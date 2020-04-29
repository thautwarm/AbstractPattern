module AbstractPattern

export spec_gen, runterm, MK, RedyFlavoured, TypeObject
export and, or, literal, and, wildcard, decons,
       guard, effect, metadata, self
export PatternCompilationError, Target, PatternImpl, PComp
export APP, CachablePre, NoncachablePre, NoPre
export ChainDict, for_chaindict, child
include("DataStructure.jl")
include("Target.jl")
include("PatternSignature.jl")
include("Print.jl")
include("structures/Print.jl")
include("structures/SourcePos.jl")
include("structures/TypeTagExtraction.jl")
include("ADT.jl")
include("CaseMerge.jl")
include("UserSignature.jl")
include("Retagless.jl")
include("implementations/RedyFlavoured.jl")
include("∀/BasicPatterns.jl")

@nospecialize

function MK(m::Any)
    m.backend
end

function runterm(term, xs)
    points_of_view = Dict{Function, Int}(x => i for (i, x) in enumerate(xs))
    impls = PatternImpl[x(points_of_view) for x in xs]
    term(impls)
end

function spec_gen(branches :: Vector{Pair{F, Symbol}}) where F <: Function
    cores = Branch[]
    for (branch, cont) in branches        
        pos, type, pat = runterm(branch::F, Function[term_position, tag_extract, untagless])
        push!(cores, PatternInfo(pat::TagfulPattern, pos, type::TypeObject) => cont)
    end
    split_cores = Branch[]
    case_split!(split_cores, cores)
    case_merge(split_cores)
end

end # module
