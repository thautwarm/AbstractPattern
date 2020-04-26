@nospecialize
const Global = AbstractPattern

function merge_if_not_singleton(xs)
    @assert !isempty(xs)
    length(xs) === 1 ? xs[1] : Global.or(xs)
end

"""for each pattern's alternative cases
"""
function case_split(points_of_view::Dict{Any, Int})
    viewpoint = points_of_view[case_split]
    function and(ps)
        f = length(ps) === 1 ? (x -> x) : (x -> [Global.and(x)])
        @assert !isempty(ps)
        f(map(merge_if_not_singleton, getindex.(ps, viewpoint)))
    end
    function or(ps)
        ps = getindex.(ps, viewpoint)
        vcat(ps...)
    end
    literal(val) = [Global.literal(val)]
    wildcard = [Global.wildcard]
    switch(_, _) = error("no switch construct should occur here")
    capture(n) = [Global.capture(n)]
    decons(recog, ps) = [Global.decons(recog, map(merge_if_not_singleton, getindex.(ps, viewpoint)))]
    guard(pred) = [Global.guard(pred)]
    effect(perf) = [Global.effect(perf)]
    metadata(term, loc) = [Global.metadata(merge_if_not_singleton(term[viewpoint]), loc)]
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


"""for each pattern's case merging
"""
function case_merging(points_of_view::Dict{Any, Int})
    myviewpoint = points_of_view[case_merging]
    typetag_viewpoint = points_of_view[tag_extract]
    
    function or(ps)
        @assert !isempty(ps)
        hd = ps[1]
        prevt = hd[typetag_viewpoint]
        switches = []
        
        active_switch_cases = Pair{TypeObject, Any}[
            prevt => hd[myviewpoint]
        ]
        
        for p in view(ps, 2:length(ps))
            pt = p[typetag_viewpoint]
            pt === prevt && continue
            if typeintersect(pt, prevt) === Base.Bottom &&
                all(Base.Bottom === typeintersect(typetag, pt) for (typetag, _) in active_switch_cases)
                # it's a group of orthogonal types, hence safely case split here
                push!(active_switch_cases, pt => p[myviewpoint])
            # TODO: support warning for overlapped types?
            else
                push!(switches, active_switch_cases)
                active_switch_cases = Pair{TypeObject, Any}[pt => p[myviewpoint]]
            end
            prevt = pt
        end
        if length(active_switch_cases) === 1
            init = active_switch_cases[1].second
        end
        foldr(switches, init=init) do cases, otherwise
            Global.switch(cases, otherwise)
        end
    end
end

abstract type CaseSplit end

struct Split <: CaseSplit
    body :: Int
end

struct Case <: CaseSplit
    term
    body :: CaseSplit
end

function compile_branches(::Vector{CaseSplit})

end
@specialize