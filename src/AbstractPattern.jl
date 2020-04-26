module AbstractPattern

export runterm
export and, or, literal, and, wildcard, switch, capture, decons,
       guard, effect, metadata, self
export PatternCompilationError, AbstractAccessor, PureAccessor,
       OnceAccessor, ManyTimesAccessor, Recogniser, PatternImpl

TypeObject = Union{DataType, Union}

include("PatternSignature.jl")
include("Print.jl")
include("structures/Print.jl")
include("structures/SourcePos.jl")
include("structures/TypeTagExtraction.jl")
include("ADT.jl")
include("CaseMerge.jl")

@nospecialize
function runterm(term, xs)
    points_of_view = Dict{Any, Int}(x => i for (i, x) in enumerate(xs))
    impls = PatternImpl[x(points_of_view) for x in xs]
    term(impls)
end

function spec_gen(branches :: Pair...)
    cores = Branch[]
    for (branch, cont) in branches
        pos, type, pat = runterm(branch, [term_position, tag_extract, untagless])
        push!(cores, PatternInfo(pat::TagfulPattern, pos, type::TypeObject) => cont)
    end
    split_cores = Branch[]
    case_split!(split_cores, cores)
    case_merge(split_cores)
end

using PrettyPrint

function PrettyPrint.pprint_impl(io, seq::Dict, indent, newline)
    PrettyPrint.pprint_for_seq(io, '(', ')', collect(seq), indent, newline)
end

function PrettyPrint.pprint_impl(io, t::TypeObject, indent, newline)
    print(io, repr(t))
end



spec_gen(
    or(
        literal(1),
        literal("string"),
    ) => 1,
    literal(2) => 2
) |> pprint
end # module
