struct PatternCompilationError <: Exception
    line:: Union{LineNumberNode, Nothing}
    msg::AbstractString
end

abstract type AbstractAccessor end

"""
All fields of the in-deconstructing datum are computed once together.

To avoid redundant computations when deconstructing:
we just calculate a tuple(hereafter `viewed`) from the in-deconstructing datum,
and do pattern matching on the returned tuple `viewed`.

Field `view` depends on your implementation.
For instance, it can be a function to transform a composite datum to a tuple.
"""
struct OnceAccessor{F<:Function} <: AbstractAccessor
    view::F
end


"""
Each field of the in-deconstructing datum will be computed separately.
Field `extract` depends on your implementation.
For instance, it can be a function for extracting sub-fields from the composite data
```
"""
struct ManyTimesAccessor{F<:Function} <: AbstractAccessor
    extract::F
end


struct Recogniser{F}
    tag::F
    accessor::AbstractAccessor
end

PatternImpl = NamedTuple{
    (
        :and,
        :or,
        :literal,
        :wildcard,
        :capture,
        :decons,
        :guard,
        :effect,
        :metadata
    )
}


PatternImpls = Vector{PatternImpl}

@nospecialize
and(args...) = and(collect(args))
and(ps::Vector) = function apply(impls::PatternImpls)
    xs = [p(impls) for p in ps]
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].and(me, xs)
    end
    me
end

or(args...) = or(collect(args))
or(ps::Vector) = function apply(impls::PatternImpls)
    xs = [p(impls) for p in ps]
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].or(me, xs)
    end
    me
end
literal(val) = function apply(impls::PatternImpls)
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].literal(me, val)
    end
    me
end
function wildcard(impls::PatternImpls)
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].wildcard(me)
    end
    me
end

capture(n) = function apply(impls::PatternImpls)
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].capture(me, n)
    end
    me
end

decons(recog, ps) = function apply(impls::PatternImpls)
    xs = [p(impls) for p in ps]
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].decons(me, recog, xs)
    end
    me
end

guard(pred) = function apply(impls::PatternImpls)
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].guard(me, pred)
    end
    me
end

effect(ctx_perf) = function apply(impls::PatternImpls)
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].effect(me, ctx_perf)
    end
    me
end

function metadata(term, location)
    function apply(impls::PatternImpls)
        x = term(impls)
        me = Vector{Any}(undef, length(impls))
        for i in eachindex(me)
            me[i] = impls[i].metadata(me, x, location)
        end
        me
    end
end
@specialize

const self = (
    and = and,
    or = or,
    literal = literal,
    wildcard = wildcard,
    capture = capture,
    decons = decons,
    guard = guard,
    effect = effect,
    metadata = metadata
)
