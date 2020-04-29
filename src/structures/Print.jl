@nospecialize
"""The view point of showing patterns
"""
function pretty(points_of_view::Dict{Function, Int})
    viewpoint = points_of_view[pretty]

    function and(_, ps)
        xs = Any[Print.w("(")]
        for p in ps
            push!(xs, p[viewpoint])
            push!(xs, Print.w(" && "))
        end
        pop!(xs)
        if !isempty(ps)
            push!(xs, Print.w(")"))
        end
        Print.seq(xs...)
    end

    function or(_, ps)
        xs = Any[Print.w("(")]
        for p in ps
            push!(xs, p[viewpoint])
            push!(xs, Print.w(" || "))
        end
        pop!(xs)
        if !isempty(ps)
            push!(xs, Print.w(")"))
        end
        Print.seq(xs...)
    end
    literal(_, val) = Print.w(string(val))
    wildcard(_) = Print.w("_")

    function decons(_, comp::PComp, ps)
        Print.seq(Print.w(comp.repr), Print.w("("), getindex.(ps, viewpoint)..., Print.w(")"))
    end

    function guard(_, pred)
        Print.seq(Print.w("when("), Print.w(repr(pred)), Print.w(")"))
    end

    function effect(_, eff)
        Print.seq(Print.w("do("), Print.w(repr(eff)), Print.w(")"))
    end

    function metadata(_, term, loc)
        Print.seq(term[viewpoint], Print.w("#{"), Print.w(repr(loc)), Print.w("}"))
    end

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
