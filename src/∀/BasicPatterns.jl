export P_bind, P_tuple, P_type_of, P_vector
@nospecialize
OptionalLn = Union{LineNumberNode, Nothing}
_donothing_acc = let 
    ManyTimesAccessor(
        function extract(_, _, _)
            error("impossible")
        end
    )
end

"""match by type
"""
function P_type_of(t)
    recog_type() = t
    decons(Recogniser(recog_type, _donothing_acc), [])
end


"""bind a symbol
"""
function P_bind(n::Symbol, expr::Any)
    type_of_bind() = Any
    function bind_effect!(target, scope::Dict{Symbol, Symbol}, ln::OptionalLn) 
        n′ = scope[n] = gensym(n)
        :($(n′) = $expr)
    end
    effect(bind_effect!)
end

"""deconstruct a tuple
"""
function P_tuple(fields::AbstractArray)
    type_of_tuple(xs...) = Tuple{xs...}
    decons(
        Recogniser(
            type_of_tuple,
            OnceAccessor(
                function view(tp, n_args::Int)
                    tp
                end
            )
        ),
        fields
    )
end

"""deconstruct a tuple
"""
function P_vector(fields::AbstractArray)
    function type_of_vector(types...)
        if length(types) == 0
            AbstractArray{Any, 1}
        else
            AbstractArray{T, 1} where T <: reduce(typejoin, types)
        end
    end
    extract(arr, i::Int, n_args::Int) = :($arr[$i])
    decons(
        Recogniser(
            type_of_bind,
            ManyTimesAccessor(extract)
        ),
        fields
    )
end
@specialize
