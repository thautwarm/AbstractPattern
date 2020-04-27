module UserSitgnature

export and, or, literal, and, wildcard, decons,
       guard, effect, self

PatternUse = NamedTuple{
    (
        :and,
        :or,
        :literal,
        :wildcard,
        :decons,
        :guard,
        :effect
    )
}

@nospecialize
_empty_ntuple = NamedTuple()
and(ps::Vector, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    xs = [p(impl) for p in ps]
    impl.and(xs, config)
end

or(ps::Vector, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    xs = [p(impl) for p in ps]
    impl.or(xs, config)
end
literal(val, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)    
    impl.literal(val, config)
end
wildcard(config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    impl.wildcard(config)
end

decons(tcons, guard1, view, guard2, extract, ps, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    xs = [p(impl) for p in ps]
    guard1′ = guard1(impl)
    guard2′ = guard2(impl)
    impl.decons(tcons, guard1′, view, guard2′, extract, xs, config)
end

guard(pred, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    impl.guard(pred, config)
end

effect(ctx_perf, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    impl.effect(ctx_perf, config)
end

const self = (
    and = and,
    or = or,
    literal = literal,
    wildcard = wildcard,
    decons = decons,
    guard = guard,
    effect = effect
)

end
@specialize