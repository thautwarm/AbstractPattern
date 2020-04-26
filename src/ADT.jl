@nospecialize
export TagfulPattern, And, Or,
       Literal, Wildcard, Capture,
       Deconstrucution, Guard, Effect,
       untagless, TagfulPattern,
       PatternInfo

abstract type TagfulPattern end


struct PatternInfo
    pattern ::TagfulPattern
    metatag :: Union{Nothing, LineNumberNode}
    typetag :: TypeObject
end

struct And <: TagfulPattern
    ps :: Vector{PatternInfo}
end

struct Or <: TagfulPattern
    ps :: Vector{PatternInfo}
end

struct Literal{T} <: TagfulPattern
    val :: T
end

struct Wildcard <: TagfulPattern
end

struct Capture <: TagfulPattern
    n :: Union{String, Symbol}
end

struct Deconstrucution <: TagfulPattern
    recog :: Recogniser
    params :: Vector{PatternInfo}
end

struct Guard <: TagfulPattern
    predicate :: Any
end

struct Effect <: TagfulPattern
    perform :: Any
end

function untagless(points_of_view::Dict{Any, Int})
    myviewpoint = points_of_view[untagless]
    metaviewpoint = points_of_view[term_position]
    typetag_viewpoint = points_of_view[tag_extract]
    mk_info(all_info)::PatternInfo = PatternInfo(
        all_info[[myviewpoint, metaviewpoint, typetag_viewpoint]]...
    )
    ! = mk_info
    (
        and = ps -> And(PatternInfo[!e for e in ps]),
        or= ps -> Or(PatternInfo[!e for e in ps]),
        literal = Literal,
        wildcard = Wildcard(),
        capture = Capture,
        decons = (recog, ps) -> Deconstrucution(recog, PatternInfo[!p for p in ps]),
        guard = Guard,
        effect = Effect,
        metadata = (term, _) -> term[myviewpoint]
    )
end
@specialize    