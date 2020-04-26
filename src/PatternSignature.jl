struct PatternCompilationError <: Exception
    line::LineNumberNode
    msg::AbstractString
end

abstract type AbstractAccessor end
"""
the field accessing of a composite datum is pure.
e.g., for tuples:
    `tuple_accessor = PureAccessor()`
"""
struct PureAccessor <: AbstractAccessor end

"""
All fields of the in-deconstructing datum are computed once together.

To avoid redundant computations when deconstructing:
we just calculate a tuple(hereafter `viewed`) from the in-deconstructing datum,
and do pattern matching on the returned tuple `viewed`.

e.g., for active patterns/view patterns
    ```
    MyPattern_accessor = 
        OnceAccessor(
            function (x)
                if x < 2
                    x * 2, g(x)
                else
                    (x, x)
                end
            end
        )
    @match 1 begin
        MyPattern(a, b) => a + b
    end
    <=>
    @match MyPattern_accessor.view(1) begin
        (a, b) => a + b
    end
    ```
"""
struct OnceAccessor{F<:Function} <: AbstractAccessor
    view::F
end


"""
Each field of the in-deconstructing datum will be computed separately.
```
MyPattern_accessor = 
    ManyTimesAccessor(
        let
            len(_) = 0
            len(_::Int) = 2
            len
        end,
        function (x, i)
            if i == 1
                return x + 2
            else
                return 3
            end
        end
    )
@match 1 begin
    MyPattern(a, b) => a + b
end
<=>
var = 1
@match MyPattern_accessor.extract(var, 1) begin
    a =>
        @match MyPattern_accessor.extract(var, 2) begin
            b => a + b
        end
end
```
"""
struct ManyTimesAccessor{Len<:Function,F<:Function} <: AbstractAccessor
    length_of::Len
    extract::F
end


struct Recogniser{F}
    tag::Type{F}
    accessor::AbstractAccessor
end

PatternImpl = NamedTuple{
    (
        :and,
        :or,
        :literal,
        :wildcard,
        :switch,
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
    map(impls) do impl
        impl.and(xs)
    end
end

or(args...) = or(collect(args))
or(ps::Vector) = function apply(impls::PatternImpls)
    xs = [p(impls) for p in ps]
    map(impls) do impl
        impl.or(xs)
    end
end
literal(val) = function apply(impls::PatternImpls)
    map(impls) do impl
        impl.literal(val)
    end
end
function wildcard(impls::PatternImpls)
    map(impls) do impl
        impl.wildcard
    end
end

switch(vs::Vector{Pair}, otherwise) = function apply(impls::PatternImpls)
    xs = [k => p(impls) for (k, p) in vs]
    map(impls) do impl
        impl.switch(xs, otherwise(impls))
    end
end
capture(n) = function apply(impls::PatternImpls)
    map(impls) do impl
        impl.capture(n)
    end
end


decons(recog, ps) = function apply(impls::PatternImpls)
    xs = [p(impls) for p in ps]
    map(impls) do impl
        impl.decons(recog, xs)
    end
end

guard(pred) = function apply(impls::PatternImpls)
    map(impls) do impl
        impl.guard(pred)
    end
end

effect(ctx_perf) = function apply(impls::PatternImpls)
    map(impls) do impl
        impl.effect(ctx_perf)
    end
end

function metadata(term, location)
    function apply(impls::PatternImpls)
        x = term(impls)
        tp = map(impls) do impl
            impl.metadata(x, location)
        end
    end
end
@specialize

const self = (
    and = and,
    or = or,
    literal = literal,
    wildcard = wildcard,
    switch = switch,
    capture = capture,
    decons = decons,
    guard = guard,
    effect = effect,
    metadata = metadata
)
