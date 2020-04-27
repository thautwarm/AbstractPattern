using AbstractPattern
using Test
using PrettyPrint


function PrettyPrint.pprint_impl(io, seq::Dict, indent, newline)
    PrettyPrint.pprint_for_seq(io, '(', ')', collect(seq), indent, newline)
end

function PrettyPrint.pprint_impl(io, ::Type{T}, indent, newline) where T
    print(io, repr(T))
end

donothing_acc = ManyTimesAccessor(
    _ -> 0,
    (_, _) -> error("impossible")
)

type_of(t) =
    let recog_type(_...) = t
        decons(Recogniser(recog_type, donothing_acc), [])
    end

case = spec_gen(
    or(
        literal(1),
        literal("string"),
    ) => :a,

    literal(2) => :b,

    guard((_, _, _) -> :some_cond) => :c,
    
    type_of(Symbol) => :d,

    literal(3) => :e
)

# pprint(case)


code =
    compile_spec(case,
        :(do_something()),
        nothing
    )

println(code)


@testset "AbstractPattern.jl" begin
    # Write your own tests here.
end
