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

`compile_spec` is my flavoured implementation, which generates Julia AST:

```julia
donothing_acc = ManyTimesAccessor(
    _ -> 0,
    (_, _) -> error("impossible")
)

type_of(t) =
    let recog_type(_...) = t
        decons(Recogniser(recog_type, donothing_acc), [])
    end

case = spec_gen(
    or(
        literal(1),
        literal("string"),
    ) => :a,

    literal(2) => :b,

    guard((_, _, _) -> :some_cond) => :c,
    
    type_of(Symbol) => :d,

    literal(3) => :e
)


code =
    compile_spec(case,
        :(do_something()),
        nothing
    )

println(code)
```
=>

```julia
begin
    var"##do_something()#253" = do_something()
    if String isa var"##do_something()#253"
        if var"##do_something()#253" == "string"
            #= line 267 =# @goto a
        end
    end
    if Int64 isa var"##do_something()#253"
        if var"##do_something()#253" == 1
            #= line 267 =# @goto a
        end
        if var"##do_something()#253" == 2
            #= line 267 =# @goto b
        end
    end
    if some_cond
        #= line 267 =# @goto c
    end
    if Int64 isa var"##do_something()#253"
        if var"##do_something()#253" == 3
            #= line 267 =# @goto e
        end
    end
    if Symbol isa var"##do_something()#253"
        if var"##do_something()#253" isa Symbol
            #= line 267 =# @goto d
        end
    end
    error("no pattern matched")
end
```