using AbstractPattern
using Test


function test()

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

        literal(3) => :e,

        P_vector([
            literal(1),
            and(P_type_of(AbstractFloat),  P_capture(:a)),
            or(literal(1), P_type_of(Real))
        ]) =>  :f,

        P_tuple([
            literal(5),
            P_type_of(AbstractString),
            P_tuple([
                P_type_of(Int),
                P_type_of(Int)
            ])
        ]) =>  :g,

        P_slow_view(x -> :($x, $x),
            P_tuple([P_type_of(Int), P_type_of(Int)])
        ) => :h
    ]
)

end


println(test())
