using AbstractPattern
using Test
using PrettyPrint


function PrettyPrint.pprint_impl(io, seq::Dict, indent, newline)
    PrettyPrint.pprint_for_seq(io, '(', ')', collect(seq), indent, newline)
end

function PrettyPrint.pprint_impl(io, ::Type{T}, indent, newline) where T
    print(io, repr(T))
end
case = spec_gen(
    or(
        literal(1),
        literal("string"),
    ) => :a,

    literal(2) => :b,
    guard((target, scope, ln) -> :some_cond)  => :c,
    literal(1) => :d
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
