using AbstractPattern
using AbstractPattern.BasicPatterns
using Test

const backend = MK(RedyFlavoured)

function test()

pairit(x) = :(complex_func1($x), complex_func2($x))

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

        # pairit(x) = :(complex_func1($x), complex_func2($x))
        P_slow_view(pairit,
            [P_type_of(Int), P_type_of(Int)],
        ) => :h,
        P_slow_view(pairit,
            [P_type_of(String), P_type_of(Int)],
        ) => :i
    ]
)

end


# println(test())   


untyped_view1(x) = :(f1($x))
untyped_view2(x) = :(f2($x))

code = backend(
    :val,
    [
        and(
            P_slow_view(untyped_view1, []),
            P_slow_view(untyped_view2,
                [P_type_of(Int), P_type_of(Int)],
            )
        ) => :h,
        P_slow_view(untyped_view2,
            [
                P_type_of(String),
                P_slow_view(untyped_view1, [])
            
            ],
        ) => :i
    ]
)
println(code)