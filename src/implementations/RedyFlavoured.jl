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
    cond.stmt isa Union{Bool, Int, Float64, Nothing} #= shall contain more literal typs =# && return
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
        function apply(env, target::Target{true})
            target′ = target.with_repr(gensym(string(target.repr)), Val(false))
            AndCond(
                TrueCond(:($(target′.repr) = $(target.repr))),
                f(env, target′)
            )
        end
        function apply(env, target::Target{false})
            f(env, target)
        end
        apply
    end

    wildcard(_) = (env, target::Target) -> TrueCond()

    literal(v, config) = function (env, target::Target)
        CheckCond(:($(target.repr) == $(QuoteNode(v))))
    end

    and2(p1, p2) = function (env, target::Target{false})
        AndCond(
            p1(env, target),
            p2(env, target)
        )
    end

    function and(ps, config)
        @assert !isempty(ps)
        cache(foldl(and2, ps))
    end


    function or(ps, config)
        @assert !isempty(ps)
        function (env, target::Target{false})
            or_checks = Cond[]
            envs = Dict{Symbol,Symbol}[]
            for p in ps
                let env′ = copy(env)
                    push!(or_checks, p(env′, target.clone))
                    push!(envs, env′)
                end
            end

            # check the change of scope discrepancies for all branches
            all_keys = union!(Set{Symbol}(), map(keys, envs)...)
            for key in all_keys
                if !allsame(Symbol[env[key] for env in envs])
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
            foldr(OrCond, or_checks)
        end |> cache
    end

    # C(p1, p2, .., pn)
    # pattern = (target: code, remainder: code) -> code
    function decons(_, guard, view, extract, ps, config)
        ty = config.type
        function (env, target::Target{false})
            chk = if target.type <: ty
                TrueCond()
            else
                target.type_narrow!(ty)
                CheckCond(:($(target.repr) isa $ty))
            end
            chk = AndCond(chk, guard(env, target))
            
            if view === AbstractPattern.identity_view
                sym = target.repr
            else
                sym = gensym(string(target.repr))
                chk = AndCond(
                    chk,
                    TrueCond(:($sym = $(view(sym, env, config.ln))))
                )
            end
            for i in eachindex(ps)
                field_target = Target{true}(extract(sym, i), Ref{TypeObject}(Any))
                chk = AndCond(chk, ps[i](env, field_target))
            end
            chk
        end |> cache
    end

    function guard(pred, config)
        function (env, target::Target{false})
            expr = pred(target.repr, env, config.ln)
            expr === true ? TrueCond() : CheckCond(expr)
        end |> cache
    end

    function effect(perf, config)
        function (env, target::Target{false})
            TrueCond(perf(target.repr, env, config.ln))
        end |> cache
    end

    (
        and = and,
        or = or,
        literal = literal,
        wildcard = wildcard,
        decons = decons,
        guard = guard,
        effect = effect,
    )
end

const redy_impl = myimpl()

function compile_spec!(
    scope :: Dict{Symbol, Symbol},
    suite::Vector{Any},
    x::Shaped,
    target::Target{IsComplex},
) where {IsComplex}
    if IsComplex && !(x.case isa Leaf)
        sym = gensym(string(target.repr))
        push!(suite, :($sym = $(target.repr)))
        target = target.with_repr(sym, Val(false))
    end
    mkcond = re_tagless(x.pattern)(redy_impl)
    ln = x.pattern.metatag
    if !isnothing(ln)
        push!(suite, ln)
    end
    cond = mkcond(scope, target)
    conditional_expr = to_expression(cond)
    true_clause = Expr(:block)
    compile_spec!(scope, true_clause.args, x.case, target)
    push!(suite, 
        conditional_expr === true ?
            true_clause :
            Expr(:if, conditional_expr, true_clause)
    )
end

function compile_spec!(scope :: Dict{Symbol, Symbol}, suite::Vector{Any}, x::Leaf, target::Target)
    for (k, v) in scope
        push!(suite, :($k = $v))  # hope this gets optimized to move semantics...
    end
    push!(suite, Expr(:macrocall, Symbol("@goto"), LineNumberNode(@__LINE__), x.cont))
end

function compile_spec!(
    scope :: Dict{Symbol, Symbol},
    suite::Vector{Any},
    x::SwitchCase,
    target::Target{IsComplex},
) where {IsComplex}
    if IsComplex
        sym = gensym(string(target.repr))
        push!(suite, :($sym = $(target.repr)))
        target = target.with_repr(sym, Val(false))
    else
        sym = target.repr
    end

    for (ty, case) in x.cases
        true_clause = Expr(:block)
        compile_spec!(copy(scope), true_clause.args, case, target.with_type(ty))
        push!(suite, Expr(:if, :($sym isa $ty), true_clause))
    end
end

function compile_spec!(
    scope :: Dict{Symbol, Symbol},
    suite::Vector{Any},
    x::EnumCase,
    target::Target{IsComplex},
) where {IsComplex}
    if IsComplex
        sym = gensym(string(target.repr))
        push!(suite, :($sym = $(target.repr)))
        target = target.with_repr(sym, Val(false))
    end
    for case in x.cases
        compile_spec!(copy(scope), suite, case, target.clone)
    end
end

function compile_spec(target::Any, case::AbstractCase, ln::Union{LineNumberNode,Nothing})
    target = target isa Symbol ?
        Target{false}(target, Ref{TypeObject}(Any)) :
        Target{true}(target, Ref{TypeObject}(Any))


    ret = Expr(:block)
    suite = ret.args
    scope = Dict{Symbol, Symbol}()
    compile_spec!(scope, suite, case, target)
    if !isnothing(ln)
        # TODO: better trace
        msg = "no pattern matched, at $ln"
        push!(suite, :(error($msg)))
    else
        push!(suite, :(error("no pattern matched")))
    end
    length(suite) === 1 ?
        suite[1] :
        ret
end

"""compile a series of `Term => Symbol`(branches) to a Julia expression
"""
function backend(
    expr_to_match::Any,
    branches::Vector{Pair{F,Symbol}},
    ln::Union{LineNumberNode,Nothing} = nothing,
) where {F<:Function}
    spec = spec_gen(branches)
    compile_spec(expr_to_match, spec, ln)
end
end
