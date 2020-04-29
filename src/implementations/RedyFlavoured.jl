module RedyFlavoured
using  AbstractPattern

Config = NamedTuple{(:type, :ln)}
Scope = ChainDict{Symbol,Symbol}
ViewCache = ChainDict{Pair{TypeObject, Any}, Tuple{Symbol, Bool}}

struct CompileEnv
    # Dict(user_defined_name => actual_name). mangling for scope safety
    scope :: Scope
    # Dict(view => (viewed_cache_symbol => guarantee_of_defined?))
    view_cache :: ViewCache
end

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
    cond.stmt isa Union{Bool,Int,Float64,Nothing} && return #= shall contain more literal typs =#
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

allsame(xs::Vector) = any(e -> e == xs[1], xs)



function myimpl()

    function cache(f)
        function apply(env::CompileEnv, target::Target{true})::Cond
            target′ = target.with_repr(gensym(string(target.repr)), Val(false))
            AndCond(TrueCond(:($(target′.repr) = $(target.repr))), f(env, target′))
        end
        function apply(env::CompileEnv, target::Target{false})::Cond
            f(env, target)
        end
        apply
    end

    wildcard(::Config) = (::CompileEnv, target::Target) -> TrueCond()

    literal(v, config::Config) =
        function ap_literal(::CompileEnv, target::Target)::Cond
        CheckCond(:($(target.repr) == $(QuoteNode(v))))
    end

    function and(ps::Vector{<:Function}, config::Config)
        @assert !isempty(ps)
        function ap_and_head(env::CompileEnv, target::Target{false})::Cond
            hd = ps[1]::Function
            tl = view(ps, 2:length(ps))
            init = hd(env, target)

            # the first conjuct must be executed, so the computation can get cached:
            # e.g.,
            #   match val with
            #   | View1 && View2 ->
            # and we know `View1` must be cached.
            (computed_guarantee′, env′, ret) = 
                foldl(tl, init=(true, env, init)) do (computed_guarantee, env, last), p
                    # `TrueCond` means the return expression must be evaluated to `true`
                    computed_guarantee′ = computed_guarantee && last isa TrueCond
                    if computed_guarantee′ === false && computed_guarantee === true
                        view_cache = env.view_cache
                        view_cache′ = child(view_cache)
                        view_cache_change = view_cache′.cur
                        env = CompileEnv(env.scope, view_cache′)
                    end
                    computed_guarantee′, env, AndCond(last, p(env, target))
                end
            
            if computed_guarantee′ === false
                for (typed_viewer, (sym, _)) in env′.view_cache.cur
                    env.view_cache.cur[typed_viewer] = (sym, false)
                end
            end
            ret

        end |> cache
    end


    function or(ps::Vector{<:Function}, config::Config)
        @assert !isempty(ps)
        function ap_or(env::CompileEnv, target::Target{false})::Cond
            or_checks = Cond[]
            scope = env.scope
            view_cache = env.view_cache
            scopes = Dict{Symbol,Symbol}[]
            for p in ps
                scope′ = child(scope)
                env′ = CompileEnv(scope′, view_cache)
                push!(or_checks, p(env′, target.clone))
                push!(scopes, scope′.cur)
            end
            
            # check the change of scope discrepancies for all branches
            intersected_new_names = intersect!(Set{Symbol}(),  map(keys, scopes)...)
            if length(intersected_new_names) !== 1
                for key in intersected_new_names
                    refresh = gensym(key)
                    for i in eachindex(or_checks)
                        check = or_checks[i]
                        old_name = get(scopes[i], key) do
                            throw(PatternCompilationError(
                                config.ln,
                                "Variables such as $key not bound in some branch!",
                            ))
                        end
                        or_checks[i] =
                            AndCond(or_checks[i], TrueCond(:($refresh = $old_name)))
                    end
                    scope[key] = refresh
                end
            else
                key = intersected_new_names[end]
                scope[key] = scopes[end][key]
            end
            foldr(OrCond, or_checks)
        end |> cache
    end

    # C(p1, p2, .., pn)
    # pattern = (target: code, remainder: code) -> code
    function decons(
        comp::PComp,
        ps::Vector,
        config::Config,
    )
        ty = config.type
        ln = config.ln

        function ap_decons(env, target::Target{false})::Cond
            # type check
            chk = if target.type <: ty
                TrueCond()
            else
                target.type_narrow!(ty)
                CheckCond(:($(target.repr) isa $ty))
            end

            scope = env.scope
            # compute pattern viewing if no guarantee of being computed
            view_cache = env.view_cache.cur

            function static_memo(
                f::Function,
                op::APP;
                depend::Union{Nothing, APP}=nothing
            )
                if op isa NoPre
                    nothing
                elseif op isa NoncachablePre
                    f(nothing)
                else
                    cache_key = depend === nothing ? op : (depend => op)
                    cache_key = ty => cache_key
                    cached = get(view_cache, cache_key, nothing)::Union{Tuple{Symbol, Bool}, Nothing}
                    if cached === nothing
                        cached_sym = gensym(string(target.repr))
                        computed_guarantee = false
                    else
                        (cached_sym, computed_guarantee) = cached
                    end
                    if !computed_guarantee
                        f(cached_sym)
                        view_cache[cache_key] = (cached_sym, true)
                        cached_sym
                    else
                        cached_sym
                    end
                end
            end

            static_memo(comp.guard1) do cached_sym
                guard_expr = comp.guard1(target.repr)
                if cached_sym !== nothing
                    guard_cond = AndCond(
                        TrueCond(:($cached_sym = $guard_expr)),
                        CheckCond(cached_sym)
                    )
                else
                    guard_cond = CheckCond(guard_expr)
                end
                chk = AndCond(chk, guard_cond)
            end

            viewed_sym = target.repr
            viewed_sym′ = static_memo(comp.view) do cached_sym
                viewed_expr = comp.view(target.repr)
                if cached_sym === nothing
                    viewed_sym′ = gensym(string(viewed_sym))
                else
                    viewed_sym′ = cached_sym
                end
                chk = AndCond(chk, TrueCond(:($viewed_sym′ = $viewed_expr)))
                viewed_sym′
            end
            if viewed_sym′ !== nothing
                viewed_sym = viewed_sym′
            end
            
            static_memo(comp.guard2; depend=comp.view) do cached_sym
                guard_expr = comp.guard2(viewed_sym)
                if cached_sym !== nothing
                    guard_cond = AndCond(
                        TrueCond(:($cached_sym = $guard_expr)),
                        CheckCond(cached_sym)
                    )
                else
                    guard_cond = CheckCond(guard_expr)
                end
                chk = AndCond(chk, guard_cond)
            end

            extract = comp.extract
            for i in eachindex(ps)
                p = ps[i] :: Function
                field_target = Target{true}(extract(viewed_sym, i), Ref{TypeObject}(Any))
                env′ = CompileEnv(scope, ViewCache())
                chk = AndCond(chk, p(env′, field_target))
            end
            chk
        end |> cache
    end

    function guard(pred::Function, config::Config)
        function ap_guard(env, target::Target{false})::Cond
            expr = pred(target.repr, env.scope, config.ln)
            expr === true ? TrueCond() : CheckCond(expr)
        end |> cache
    end

    function effect(perf::Function, config::Config)
        function ap_effect(env, target::Target{false})::Cond
            TrueCond(perf(target.repr, env.scope, config.ln))
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
    env::CompileEnv,
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
    cond = mkcond(env, target)
    conditional_expr = to_expression(cond)
    true_clause = Expr(:block)
    compile_spec!(env, true_clause.args, x.case, target)
    push!(
        suite,
        conditional_expr === true ? true_clause : Expr(:if, conditional_expr, true_clause),
    )
end

function compile_spec!(
    env::CompileEnv,
    suite::Vector{Any},
    x::Leaf,
    target::Target,
)
    for_chaindict(env.scope) do k, v
        push!(suite, :($k = $v))  # hope this gets optimized to move semantics...
    end
    push!(suite, Expr(:macrocall, Symbol("@goto"), LineNumberNode(@__LINE__), x.cont))
end

function compile_spec!(
    env::CompileEnv,
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
        # create new `view_cache` as only one case will be executed
        env′ = CompileEnv(child(env.scope), child(env.view_cache))
        compile_spec!(env′, true_clause.args, case, target.with_type(ty))
        push!(suite, Expr(:if, :($sym isa $ty), true_clause))
    end
end

function compile_spec!(
    env::CompileEnv,
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
        # use old view_cache:
        # cases are tried in order,
        # hence `view_cache` can inherit from the previous case
        env′ = CompileEnv(child(env.scope), env.view_cache)
        compile_spec!(env, suite, case, target.clone)
    end
end

function compile_spec(target::Any, case::AbstractCase, ln::Union{LineNumberNode,Nothing})
    target = target isa Symbol ? Target{false}(target, Ref{TypeObject}(Any)) :
        Target{true}(target, Ref{TypeObject}(Any))


    ret = Expr(:block)
    suite = ret.args
    scope = Scope()
    view_cache = ViewCache()
    env = CompileEnv(scope, view_cache)
    
    compile_spec!(env, suite, case, target)
    if !isnothing(ln)
        # TODO: better trace
        msg = "no pattern matched, at $ln"
        push!(suite, :(error($msg)))
    else
        push!(suite, :(error("no pattern matched")))
    end
    length(suite) === 1 ? suite[1] : ret
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
