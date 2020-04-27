@nospecialize
"""The view point of a term's source code position.
i.e. the line number node.
"""
function term_position(points_of_view::Dict{Any, Int})
    viewpoint = points_of_view[term_position]

    function and(_, ps)
        res = getindex.(ps, viewpoint)
        i = findfirst(!isnothing, res)
        if i === nothing
            nothing
        else
            return res[i]
        end
    end

    function or(_, ps)
        res = getindex.(ps, viewpoint)
        i = findfirst(!isnothing, res)
        if i === nothing
            nothing
        else
            return res[i]
        end
    end

    literal(_, _) = nothing
    wildcard(_) = nothing

    function decons(_, tcons, guard, view, extract, ps)
        res = getindex.(ps, viewpoint)
        push!(res, guard[viewpoint])
        i = findfirst(!isnothing, res)
        if i === nothing
            nothing
        else
            return res[i]
        end
    end

    guard(_, _) = nothing
    effect(_, _) = nothing
    metadata(_, _, location) = location

    (
        and = and,
        or = or,
        literal = literal,
        wildcard = wildcard,
        decons = decons,
        guard = guard,
        effect = effect,
        metadata = metadata,
    )
end
@specialize
