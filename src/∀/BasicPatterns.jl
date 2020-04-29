export P_bind, P_tuple, P_type_of, P_vector, P_capture, P_vector3, P_slow_view
@nospecialize
OptionalLn = Union{LineNumberNode,Nothing}

struct CachablePre <: APP
    f :: Function
end
(f::CachablePre)(target) = f.f(target)

function sequence_index(viewed, i::Integer)
    :($viewed[$i])
end


function mk_type_object(i::Int, ::Type{T}) where {T}
    if isabstracttype(T)
        TypeVar(gensym(string(i)), T)
    else
        T
    end
end

"""match by type
"""
function P_type_of(t, prepr::AbstractString="isa $t")
    recog_type() = t
    comp = PComp(prepr, recog_type)
    decons(comp, [])
end


"""bind a symbol
"""
function P_bind(n::Symbol, expr::Any)
    function bind_effect!(target, scope::ChainDict{Symbol,Symbol}, ln::OptionalLn)
        n′ = scope[n] = gensym(n)
        :($(n′) = $expr)
    end
    effect(bind_effect!)
end

"""bind a symbol
"""
function P_capture(n::Symbol)
    function capture_effect!(target, scope::ChainDict{Symbol,Symbol}, ln::OptionalLn)
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
function P_tuple(fields::AbstractArray, prepr::AbstractString="Tuple")
    type_of_tuple(xs...) = Tuple{(mk_type_object(i, xs[i]) for i in eachindex(xs))...}
    comp = PComp(prepr, type_of_tuple; extract=sequence_index)
    
    decons(comp, fields)
end

"""deconstruct a vector
"""
function P_vector(fields::AbstractArray, prepr::AbstractString="1DVector")
    function type_of_vector(types...)
        if length(types) == 0
            AbstractArray{Any,1}
        else
            AbstractArray{T,1} where {T<:reduce(typejoin, types)}
        end
    end
    n_fields = length(fields)
    function pred(target)
        :(length($target) === $n_fields)
    end
    comp = PComp(prepr, type_of_vector; guard1=NoncachablePre(pred), extract=sequence_index)
    decons(comp, fields)
end

"""deconstruct a vector in this way: [a, b, c, pack..., d, e]
"""
function P_vector3(init::AbstractArray, pack, tail::AbstractArray, prepr::AbstractString = "1DVector Pack")
    n1 = length(init)
    n2 = length(tail)
    min_len = length(init) + length(tail)
    function type_of_vector(types...)
        if length(types) == 0
            AbstractArray{Any,1}
        else
            AbstractArray{T,1} where {T<:reduce(typejoin, types)}
        end
    end
    function extract(arr, i::Int)
        if i <= n1
            :($arr[$i])
        elseif i === n1 + 1
            :(view($arr, n1:length($arr)-n2))
        else
            incr = i - n1 - 1
            :(arr[end-n2+incr])
        end
    end
    function pred(target, scope, ln)
        :(length($target) >= $min_len)
    end
    comp = PComp(prepr, type_of_vector; guard1=NoncachablePre(pred), extract=extract)
    decons(comp, [init; pack; tail])
end


"""untyped view pattern
"""
function P_slow_view(trans, ps, prepr::AbstractString="ViewBy($trans)")
    function type_of_slow_view(args...)
        Any
    end
    
    n_fields = length(ps)
    function post_guard(viewed_tuple)
        :($viewed_tuple isa Tuple && length($viewed_tuple) === $n_fields)
    end

    comp = PComp(
        prepr, type_of_slow_view;
        view=CachablePre(trans),
        guard2=NoncachablePre(post_guard),
        extract=sequence_index
    )
    decons(comp, ps)
end

"""typed view pattern
"""
function P_fast_view(tcons, trans, ps, prepr="ViewBy($trans, typecons=$tcons)")
    function type_of_fast_view(args...)
        tcons(args...)
    end

    n_fields = length(ps)
    function post_guard(viewed_tuple)
        :($viewed_tuple isa Tuple && length($viewed_tuple) === $n_fields)
    end

    comp = PComp(
        prepr, type_of_fast_view;
        view=CachablePre(trans),
        guard2=NoncachablePre(post_guard),
        extract = sequence_index
    )
    decons(comp, ps)
end

@specialize
