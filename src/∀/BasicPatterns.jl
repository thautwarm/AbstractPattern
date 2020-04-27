export P_bind, P_tuple, P_type_of, P_vector, P_capture
@nospecialize
OptionalLn = Union{LineNumberNode,Nothing}

function mk_type_object(i::Int, ::Type{T}) where T
    if isabstracttype(T)
        TypeVar(gensym(string(i)), T)
    else
        T
    end
end
"""match by type
"""
function P_type_of(t)
    recog_type() = t
    decons(recog_type)
end


"""bind a symbol
"""
function P_bind(n::Symbol, expr::Any)
    function bind_effect!(target, scope::Dict{Symbol,Symbol}, ln::OptionalLn)
        n′ = scope[n] = gensym(n)
        :($(n′) = $expr)
    end
    effect(bind_effect!)
end

"""bind a symbol
"""
function P_capture(n::Symbol)
    function capture_effect!(target, scope::Dict{Symbol,Symbol}, ln::OptionalLn)
        if target isa Symbol
            scope[n] = target
            return nothing
        end
        n′ = scope[n] = gensym(n)
        :($(n′) = $target)
    end
    effect(capture_effect!)
end

"""deconstruct a tuple
"""
function P_tuple(fields::AbstractArray)
    type_of_tuple(xs...) = Tuple{(mk_type_object(i, xs[i]) for i in eachindex(xs))...}
    decons(type_of_tuple; extract = function extract(expr, i)
        :($expr[$i])
    end, ps = fields)
end

"""deconstruct a vector
"""
function P_vector(fields::AbstractArray)
    function type_of_vector(types...)
        if length(types) == 0
            AbstractArray{Any,1}
        else
            AbstractArray{T,1} where {T<:reduce(typejoin, types)}
        end
    end
    extract(arr, i::Int) = :($arr[$i])
    function pred(target, scope, ln)
        :(length($target) === $(length(fields)))
    end
    decons(type_of_vector; guard=guard(pred), extract=extract, ps=fields)
end
@specialize
