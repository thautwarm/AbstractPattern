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

        literal(2) => :b,

        guard((_, _, _) -> :some_cond) => :c,
        
        P_type_of(Symbol) => :d,

        literal(3) => :e
    ]
)

println(code)