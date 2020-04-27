module RedyFlavoured

using AbstractPattern

abstract type Cond end
struct AndCond <: Cond
    left::Cond
    right::Cond
end

struct OrCond <: Cond
    left::Cond
    right::Cond
end

struct TrueCond <: Cond
    stmt::Any
end

TrueCond() = TrueCond(true)

struct CheckCond <: Cond
    expr::Any
end

struct Target{IsComplex}
    repr::Any
end

"""
build to disjunctive forms
"""
function build_readable_expression!(
    exprs::Vector{Any},
    following_stmts::Vector{Any},
    cond::CheckCond,
)
    expr = cond.expr
    if !isempty(following_stmts)
        expr = Expr(:block, following_stmts..., expr)
        empty!(following_stmts)
    end
    push!(exprs, expr)
end

function build_readable_expression!(
    exprs::Vector{Any},
    following_stmts::Vector{Any},
    cond::TrueCond,
)
    cond.stmt === true && return
    push!(following_stmts, cond.stmt)
    nothing
end

function build_readable_expression!(
    exprs::Vector{Any},
    following_stmts::Vector{Any},
    cond::AndCond,
)
    build_readable_expression!(exprs, following_stmts, cond.left)
    build_readable_expression!(exprs, following_stmts, cond.right)
end

function build_readable_expression!(
    exprs::Vector{Any},
    following_stmts::Vector{Any},
    cond::OrCond,
)
    exprs′ = []
    following_stmts′ = []
    build_readable_expression!(exprs′, following_stmts′, cond.left)
    left = to_expression(exprs′, following_stmts′)

    empty!(exprs′)
    empty!(following_stmts′)
    right = build_readable_expression!(exprs′, following_stmts′, cond.right)

    bool_or = Expr(:||, left, right)
    if !isempty(following_stmts)
        bool_or = Expr(:block, following_stmts..., bool_or)
        empty!(following_stmts)
    end

    push!(exprs, bool_or)
end

function to_expression(cond::Cond)
    exprs = []
    following_stmts = []
    build_readable_expression!(exprs, following_stmts, cond)
    to_expression(exprs, following_stmts)
end

function to_expression(exprs::Vector{Any}, following_stmts::Vector)
    bool_and(a, b) = Expr(:&&, a, b)
    if isempty(following_stmts)
        isempty(exprs) && return true
        foldr(bool_and, exprs)
    else
        init = Expr(:block, following_stmts..., true)
        foldr(bool_and, exprs, init = init)
    end
end

allsame(xs) = any(e -> e == xs[1], xs)

function myimpl()

    function cache(f)
        function apply(env, target::Target{true}, checks)
            target′ = Target{false}(gensym(string(target.repr)))
            AndCond(:($(target′.repr) = $(target.repr)), f(env, target′, checks))
        end
        function apply(env, target::Target{false}, checks)
            f(env, target, checks)
        end
        apply
    end

    wildcard(_) = (env, target::Target, checks) -> checks

    capture(sym::Symbol, config) = function (env, target::Target, checks)
        actual_sym = gensym(sym)
        env[sym] = actual_sym
        AndCond(TrueCond(:($actual_sym = target.repr)), checks)
    end
    literal(v, config) = function (env, target::Target, checks)
        AndCond(CheckCond(:($(target.repr) == $v)), checks)
    end

    and2(p1, p2) = function (env, target::Target{false}, checks)
        p1(env, target, p2(env, target, checks))
    end

    function and(ps, config)
        @assert !isempty(ps)
        cache(foldr(and2, ps))
    end


    function or(ps, config)
        @assert !isempty(ps)
        function (env, target::Target{false}, checks)
            or_checks = Cond[]
            envs = Dict{Symbol,Symbol}[]
            for p in ps
                let env′ = copy(env)
                    push!(or_checks, p(env′, target, TrueCond(true)))
                    push!(envs, env′)
                end
            end

            # check the change of scope discrepancies for all branches
            all_keys = union!(Set{Symbol}(), map(keys, envs)...)
            for key in all_keys
                if !allsame(env[key] for env in envs)
                    refresh = gensym(key)

                    for i in eachindex(or_checks)
                        check = or_checks[i]
                        old_name = get(envs[i], key) do
                            throw(PatternCompilationError(
                                config.ln,
                                "Variables such as $key not bound in some branch!",
                            ))
                        end
                        or_checks[i] =
                            AndCond(or_checks[i], TrueCond(:($refresh = $old_name)))
                    end

                    env[key] = refresh
                else
                    env[key] = envs[end][key]
                end
            end

            AndCond(foldr(OrCond, or_checks), checks)
        end |> cache
    end

    # C(p1, p2, .., pn)
    # pattern = (target: code, remainder: code) -> code
    function decons(recog, args, config)
        accessor = recog.accessor
        n_args = length(args)
        ty = config.type
        if accessor isa ManyTimesAccessor
            function (env, target::Target{false}, checks)
                checks = foldr(1:n_args, init = checks) do i, last
                    sub_tag = Target{true}(accessor.extract(target.repr, i))
                    args[i](env, sub_tag, last)
                end
                AndCond(CheckCond(:($(target.repr) isa $ty)), checks)
            end |> cache
        elseif accessor isa OnceAccessor
            function (env, target::Target{false}, checks)
                target′ = Target{false}(gensym("once"))

                checks = foldr(1:n_args, init = checks) do i, last
                    sub_tag = Target{true}(:($(target′.repr)[$i]))
                    args[i](env, sub_tag, last)
                end
                AndCond(
                    AndCond(
                        CheckCond(:($(target.repr) isa $ty)),
                        TrueCond(:($(target′.repr) = $(accessor.view(target.repr)))),
                    ),
                    checks,
                )
            end |> cache
        else
            error("contact me to add new builtin accessors?")
        end
    end

    guard(pred, config) =
        function (env, target::Target{false}, checks)
            AndCond(
                CheckCond(pred(target.repr, env, config.ln)),
                checks,
            )
        end |> cache

    effect(perf, config) = function (env, target::Target, checks)
        AndCond(TrueCond(perf(target.repr, env, config.ln)), checks)
    end

    (
        and = and,
        or = or,
        literal = literal,
        wildcard = wildcard,
        capture = capture,
        decons = decons,
        guard = guard,
        effect = effect,
    )
end

const redy_impl = myimpl()

function compile_spec!(
    suite::Vector{Any},
    x::Shaped,
    target::Target{IsComplex}
) where {IsComplex}
    if IsComplex && !(x.case isa Leaf)
        sym = gensym(string(target.repr))
        push!(suite, :($sym = $(target.repr)))
        target = Target{false}(sym)
    end
    mkcond = re_tagless(x.pattern)(redy_impl)
    scope = Dict{Symbol,Symbol}()
    cond = mkcond(scope, target, TrueCond())
    conditional_expr = to_expression(cond)
    true_clause = Expr(:block)
    compile_spec!(true_clause.args, x.case, target)
    push!(suite, Expr(:if, conditional_expr, true_clause))
end

function compile_spec!(suite::Vector{Any}, x::Leaf, target::Target)
    push!(suite, 
        Expr(
            :macrocall,
            Symbol("@goto"),
            LineNumberNode(@__LINE__),
            x.cont
        )
    )
end

function compile_spec!(
    suite::Vector{Any},
    x::SwitchCase,
    target::Target{IsComplex}
) where {IsComplex}
    if IsComplex
        sym = gensym(string(target.repr))
        push!(suite, :($sym = $(target.repr)))
        target = Target{false}(sym)
    end
    for (ty, case) in x.cases
        true_clause = Expr(:block)
        compile_spec!(true_clause.args, case, target)
        push!(suite, Expr(
            :if,
            :($ty isa $(target.repr)),
            true_clause
        ))
    end
end

function compile_spec!(
    suite::Vector{Any},
    x::EnumCase,
    target::Target{IsComplex}
) where {IsComplex}
    if IsComplex
        sym = gensym(string(target.repr))
        push!(suite, :($sym = $(target.repr)))
        target = Target{false}(sym)
    end
    for case in x.cases
        compile_spec!(suite, case, target)
    end
end

function _compile_spec(
    case :: AbstractCase,
    target :: Any,
    ln :: Union{LineNumberNode, Nothing}
)
    target = target isa Symbol ?
        Target{false}(target) :
        Target{true}(target)
    
    ret = Expr(:block)
    suite = ret.args
    compile_spec!(suite, case, target)
    if !isnothing(ln)
        # TODO: better trace
        msg = "no pattern matched, at $ln"
        push!(suite, :(error($msg)))
    else
        push!(suite, :(error("no pattern matched")))
    end
    ret
end
end