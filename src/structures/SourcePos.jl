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

    function switch(vs, otherwise)
        for each in getindex.([p for (_, p) in vs], viewpoint)
            if each !== nothing
                return each
            end
        end
        otherwise[viewpoint]
    end

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
        switch = switch,
        capture = capture,
        decons = decons,
        guard = guard,
        effect = effect,
        metadata = metadata,
    )
end
@specialize
