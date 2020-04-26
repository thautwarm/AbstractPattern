@nospecialize
"""The view point of a term's source code position.
i.e. the line number node.
"""
function term_position(points_of_view::Dict{Any, Int})
    viewpoint = points_of_view[term_position]

    function and(ps)
        res = getindex.(ps, viewpoint)
        i = findfirst(!isnothing, res)
        if i === nothing
            nothing
        else
            return res[i]
        end
    end

    function or(ps)
        res = getindex.(ps, viewpoint)
        i = findfirst(!isnothing, res)
        if i === nothing
            nothing
        else
            return res[i]
        end
    end

    literal(_) = nothing
    wildcard = nothing

    capture(_) = nothing

    function decons(_, ps)
        res = getindex.(ps, viewpoint)
        i = findfirst(!isnothing, res)
        if i === nothing
            nothing
        else
            return res[i]
        end
    end

    guard(_) = nothing
    effect(_) = nothing
    metadata(_, location) = location

    (
        and = and,
        or = or,
        literal = literal,
        wildcard = wildcard,
        capture = capture,
        decons = decons,
        guard = guard,
        effect = effect,
        metadata = metadata,
    )
end
@specialize
