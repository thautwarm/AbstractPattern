using AbstractPattern
using Test


function test()

backend = MK(RedyFlavoured)

doubled(x) = :(complex_func1($x), complex_func2($x))

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

        # doubled(x) = :(complex_func1($x), complex_func2($x))
        P_slow_view(doubled,
            [P_type_of(Int), P_type_of(Int)],
        ) => :h,
        P_slow_view(doubled,
            [P_type_of(String), P_type_of(Int)],
        ) => :i
    ]
)


end


println(test())
