# AbstractPattern

An abstraction among pattern matching, provided with optimizations for pattern matching compilation.

## Why Optimizations

So far many implementations use **nested if-else** as the target of generating matching branches.

As a consequence, sometimes the code generation is not smart enough and could **break the type stability**.

Also, when using view patterns, it turns out to be hard to get rid of.redundant computations.

This project, is dedicated for optimizing above performance issues.


## Other Features

1. Implementations following this design require **no runtime system**, hence we can make pattern matching library only a develop time dependency. I already made one, in `implementations/RedyFlavoured.jl`.

2. The generated code is much more readable!


extensibility, etc.

## Preview

`spec_gen` is an abstract thing.

All pattern matching implementations based on this framework, like `implementations/RedyFlavoured.jl`,
can use abstractions from the directory `∀`, where many composite patterns(`tuple`, `vector`, and other deconstructors) are provided.

`RedyFlavoured` is my flavoured implementation, which generates Julia AST in the following way:

```julia
using AbstractPattern
using Test

backend = MK(RedyFlavoured)

code = backend(
    :val,
    [
        or(
            literal(1),
            literal("string"),
        ) => :a,

        literal(2) => :b,

        guard((_, _, _) -> :some_cond) => :c,
        
        P_type_of(Symbol) => :d,

        literal(3) => :e
    ]
)

println(code)
```
=>

```julia
begin
    if val isa String
        if val == "string"
            #= line 269 =# @goto a
        end
    end
    if val isa Int64
        if val == 1
            #= line 269 =# @goto a
        end
        if val == 2
            #= line 269 =# @goto b
        end
    end
    if some_cond
        #= line 269 =# @goto c
    end
    if val isa Int64
        if val == 3
            #= line 269 =# @goto e
        end
    end
    if val isa Symbol
        begin
            #= line 269 =# @goto d
        end
    end
    error("no pattern matched")
end
```