module UserSitgnature

export and, or, literal, and, wildcard, capture, decons,
       guard, effect, self

PatternUse = NamedTuple{
    (
        :and,
        :or,
        :literal,
        :wildcard,
        :capture,
        :decons,
        :guard,
        :effect
    )
}

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

capture(n::Symbol, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    impl.capture(n, config)
end

decons(recog, ps, config::NamedTuple=_empty_ntuple) = function apply(impl::PatternUse)
    xs = [p(impl) for p in ps]
    impl.decons(recog, xs, config)
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
    capture = capture,
    decons = decons,
    guard = guard,
    effect = effect
)

end