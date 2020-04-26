using AbstractPattern
using Test
using PrettyPrint

function PrettyPrint.pprint_impl(io, seq::Dict, indent, newline)
    PrettyPrint.pprint_for_seq(io, '(', ')', collect(seq), indent, newline)
end

function PrettyPrint.pprint_impl(io, ::Type{T}, indent, newline) where T
    print(io, repr(T))
end
spec_gen(
    or(
        literal(1),
        literal("string"),
    ) => 1,
    literal(2) => 2
) |> pprint


@testset "AbstractPattern.jl" begin
    # Write your own tests here.
end
