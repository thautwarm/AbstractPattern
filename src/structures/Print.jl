@nospecialize
"""The view point of showing patterns
"""
function pretty(points_of_view::Dict{Any, Int})
    viewpoint = points_of_view[pretty]

    function and(ps)
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

    function or(ps)
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
    literal(val) = Print.w(string(val))
    wildcard = Print.w("_")
    function switch(cases, otherwise)
        xs = [Print.w("switch")]
        inner = []
        for (tag, p) in cases
            push!(inner, Print.line)
            push!(inner, Print.w(repr(tag)))
            push!(inner, Print.w(" => "))
            push!(inner, p[viewpoint])
        end
        Print.seq(
            Print.w("switch"),
            Print.indent(Print.seq(inner...)),
            Print.line
        )
    end

    function capture(n)
        Print.seq(Print.w(repr(n)))
    end
    
    function decons(recog, ps)
        Print.seq(Print.w(repr(recog.tag)), Print.w("("), getindex.(ps, viewpoint)..., Print.w(")"))
    end

    function guard(pred)
        Print.seq(Print.w("when("), Print.w(repr(pred)), Print.w(")"))
    end

    function effect(eff)
        Print.seq(Print.w("do("), Print.w(repr(eff)), Print.w(")"))
    end

    function metadata(term, loc)
        Print.seq(term[viewpoint], Print.w("#{"), Print.w(repr(loc)), Print.w("}"))
    end

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