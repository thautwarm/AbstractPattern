struct PatternCompilationError <: Exception
    line::Union{LineNumberNode,Nothing}
    msg::AbstractString
end


PatternImpl = NamedTuple{
    (:and, :or, :literal, :wildcard, :decons, :guard, :effect, :metadata),
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

guard(pred) = function apply(impls::PatternImpls)
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].guard(me, pred)
    end
    me
end

"""
abstract pure process
"""
abstract type APP end

struct NoncachablePre <: APP
    callable :: Any
end
(f::NoncachablePre)(target::Any) = f.callable(target)
struct NoPre <: APP end

"""composite pattern
"""
struct PComp
    repr :: AbstractString
    tcons :: Function
    guard1 :: APP
    view :: APP
    guard2 :: APP
    extract :: Function
end

@specialize

invalid_extract(_, _) = error("impossible")

function PComp(
    repr :: AbstractString,
    tcons::Function;
    guard1::APP=NoPre(),
    view::APP=NoPre(),
    guard2::APP=NoPre(),
    extract::Function=invalid_extract,
)
    PComp(repr, tcons, guard1, view, guard2, extract)
end

@nospecialize

decons(comp::PComp, ps) = function apply(impls::PatternImpls)
    xs = [p(impls) for p in ps]
    me = Vector{Any}(undef, length(impls))
    for i in eachindex(me)
        me[i] = impls[i].decons(me, comp, xs)
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
    decons = decons,
    guard = guard,
    effect = effect,
    metadata = metadata,
)
