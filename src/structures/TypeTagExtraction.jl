@nospecialize
# term_position is from ./SourcePos.jl and,
# PatternCompilationError is from ../PatternSignature
"""the view point of the type tag for each term
"""
function tag_extract(points_of_view::Dict{Any, Int})
    viewpoint = points_of_view[tag_extract]
    viewpos = points_of_view[term_position]

    function and(many)
        @assert !isempty(many)
        ts = getindex.(many, viewpoint)
        t = reduce(typeintersect, ts)
        if t === Base.Bottom
            core_msg = "and patterns require an intersection of $(ts), which seems empty!"
            linenumbernodes = filter(!isnothing, [e[viewpos] for e in many])
            isnothing(viewpos) || isempty(linenumbernodes) ? error(core_msg) :
            throw(PatternCompilationError(linenumbernodes[1], core_msg))
        end
        t
    end

    function or(many)
        ts = getindex.(many, viewpoint)
        Union{ts...}
    end

    function literal(val)
        typeof(val)
    end

    wildcard = Any

    function switch(vs, otherwise)
        error("switch in this pass should be splitted in to non-nested `or`")
    end

    capture(_) = Any

    function decons(recog, ns)
        recog.tag
    end

    guard(_) = Any
    effect(_) = Any
    metadata(term, _) = term[viewpoint]

    (
        and = and,
        or = or,
        literal = literal,
        wildcard = wildcard,
        switch = switch,
        capture = capture,
        decons = decons,
        guard = guard,
        effect = effect,
        metadata = metadata
    )
end
@specialize