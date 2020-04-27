using AbstractPattern
using Test

backend = MK(RedyFlavoured)

code = backend(
    :val,
    [
        or(
            literal(1),
            literal("string"),
        ) => :a,

        and(literal(2), P_capture(:a)) => :b,

        guard((_, _, _) -> :some_cond) => :c,
        
        and(
            P_type_of(Symbol),
            P_bind(:c, :((val, val)))
        ) => :d,

        literal(3) => :e
    ]
)

println(code)