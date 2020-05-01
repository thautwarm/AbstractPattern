module BasicPatterns
using AbstractPattern

export P_bind, P_tuple, P_type_of, P_vector, P_capture, P_vector3, P_slow_view
export SimpleCachablePre
@nospecialize
OptionalLn = Union{LineNumberNode,Nothing}

struct SimpleCachablePre <: APP
    f :: Function
end
(f::SimpleCachablePre)(target) = f.f(target)

function sequence_index(viewed, i::Integer)
    :($viewed[$i])
end

function length_eq_check(seq, n::Int)
    if n === 0
        :(isempty($seq))
    else
        :(length($seq) === $n)
    end
end


function mk_type_object(i::Int, ::Type{T}) where {T}
    if isabstracttype(T)
        TypeVar(Symbol(:var, i), T)
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
    function type_of_tuple(xs...)
        
        ts = [mk_type_object(i, xs[i]) for i in eachindex(xs)]
        foldl(ts, init=Tuple{ts...}) do last, t
            t isa TypeVar ?
                UnionAll(t, last) :
                last
        end
    end
    comp = PComp(prepr, type_of_tuple)
    
    decons(comp, sequence_index, fields)
end

"""deconstruct a vector
"""
function P_vector(fields::AbstractArray, prepr::AbstractString="1DVector")
    function type_of_vector(types...)
        if length(types) == 0
            AbstractArray{Any,1}
        else
            Eltype = foldl(typejoin, types)
            AbstractArray{T,1} where {T<:Eltype}
        end
    end
    n_fields = length(fields)
    function pred(target)
        length_eq_check(target, n_fields)
    end
    comp = PComp(prepr, type_of_vector; guard1=NoncachablePre(pred))
    decons(comp, sequence_index, fields)
end

"""deconstruct a vector in this way: [a, b, c, pack..., d, e]
"""
function P_vector3(init::AbstractArray, pack, tail::AbstractArray, prepr::AbstractString = "1DVector Pack")
    n1 = length(init)
    n2 = length(tail)
    min_len = length(init) + length(tail)
    function type_of_vector(types...)
        Eltype = foldl(
                typejoin,
                [
                    types[1:n1]...,
                    eltype(types[n1+1]),
                    types[end-n2:end]...
                ]
            )
        AbstractArray{T,1} where {
            T<:Eltype
        }
    end
    function extract(arr, i::Int)
        if i <= n1
            :($arr[$i])
        elseif i === n1 + 1
            :(view($arr, $n1+1:length($arr)-$n2))
        else
            incr = i - n1 - 1
            :($arr[end-$(n2-incr)])
        end
    end
    function pred(target)
        :(length($target) >= $min_len)
    end
    comp = PComp(prepr, type_of_vector; guard1=NoncachablePre(pred))
    decons(comp, extract, [init; pack; tail])
end


"""untyped view pattern
"""
function P_slow_view(trans, ps, prepr::AbstractString="ViewBy($trans)")
    function type_of_slow_view(args...)
        Any
    end
    
    n_fields = length(ps)
    function post_guard(viewed_tuple)
        :($viewed_tuple isa Tuple && $(length_eq_check(viewed_tuple, n_fields)))
    end

    comp = PComp(
        prepr, type_of_slow_view;
        view=SimpleCachablePre(trans),
        guard2=SimpleCachablePre(post_guard)
    )
    decons(comp, extract, ps)
end

"""typed view pattern
"""
function P_fast_view(tcons, trans, ps, prepr::AbstractUnitRange="ViewBy($trans, typecons=$tcons)")

    n_fields = length(ps)
    function post_guard(viewed_tuple)
        :($viewed_tuple isa Tuple && $(length_eq_check(viewed_tuple, n_fields)))
    end

    comp = PComp(
        prepr, tcons;
        view=SimpleCachablePre(trans),
        guard2=NoncachablePre(post_guard)
    )
    decons(comp, sequence_index, ps)
end

@specialize
end