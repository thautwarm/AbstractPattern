# AbstractPattern

An abstraction among pattern matching, provided with optimizations for pattern matching compilation.

## Why Optimizations

So far many implementations use **nested if-else** as the target of generating matching branches.

As a consequence, sometimes the code generation is not smart enough and could **break the type stability**.

Also, when using view patterns, it turns out to be hard to get rid of.redundant computations.

This project, is dedicated for optimizing above performance issues.


## Preview

```julia
spec_gen(
    or(
        literal(1),
        literal("string"),
    ) => 1,
    
    literal(2) => 2
)
=>
AbstractPattern.SwitchCase(
  cases=(
    Pair{Union{DataType, Union},AbstractPattern.AbstractCase}(
      first=String,
      second=AbstractPattern.Shaped(
        pattern=PatternInfo(
          pattern=Literal{String}(
            val="string",
          ),
          metatag=nothing,
          typetag=String,
        ),
        case=AbstractPattern.Leaf(
          cont=1,
        ),
      ),
    ),
    Pair{Union{DataType, Union},AbstractPattern.AbstractCase}(
      first=Int64,
      second=AbstractPattern.EnumCase(
        cases=[
          AbstractPattern.Shaped(
            pattern=PatternInfo(
              pattern=Literal{Int64}(
                val=1,
              ),
              metatag=nothing,
              typetag=Int64,
            ),
            case=AbstractPattern.Leaf(
              cont=1,
            ),
          ),
          AbstractPattern.Shaped(
            pattern=PatternInfo(
              pattern=Literal{Int64}(
                val=2,
              ),
              metatag=nothing,
              typetag=Int64,
            ),
            case=AbstractPattern.Leaf(
              cont=2,
            ),
          ),
        ],
      ),
    ),
  ),
)
```