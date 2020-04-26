using AbstractPattern
failed = Val(0)

function myimpl()
    cache(f) =
        (target, body) ->
            gensym("cache_$target") |>
            TARGET -> Expr(:block, :($TARGET = $target), :($(f(TARGET, body))))


    wildcard(_) = (target, body) -> body

    capture(sym::Symbol, config) =
        (target, body) -> Expr(:let, Expr(:block, :($sym = $target)), body)

    literal(v, config) = (target, body) -> :($v == $target ? $body : $failed)

    and2(p1, p2) = (target, body) -> p1(target, p2(target, body))

    function and(ps, config)
        reduce(and2, ps)
    end

    function or(ps, config)
        RET = gensym("or")
        function or2(p1, p2)
            function (target, body)
                e1 = p1(target, body)
                e2 = p2(target, body)
                Expr(
                    :block,
                    :($RET = $e1),
                    :(function ($RET::$Val{0})::$(Union{body,Val{0}})
                        $e2
                    end),
                    :(function ($RET::$body)::$body
                        $(body())
                    end),
                    Expr(:call, RET),
                )
            end
        end
        reduce(or, ps)
    end

    # C(p1, p2, .., pn)
    # pattern = (target: code, remainder: code) -> code
    function decons(recog, args, config)
        accessor = recog.accessor
        n_args = length(args)
        ty = config.type
        if accessor isa ManyTimesAccessor
            function ret(target, body)
                foldr(1:n_args, init = body) do i, last
                    sub_tag = accessor.extract(target, i)
                    args[i](sub_tag, last)
                end
            end
        elseif accessor isa OnceAccessor
            function ret(target, body)
                n = gensym("once")
                Expr(
                    :let,
                    Expr(:block, :($n = $(accessor.view(target)))),
                    foldr(1:n_args, init = body) do i, last
                        sub_tag = :($n[$i])
                        args[i](sub_tag, last)
                    end,
                )
            end
        else
            error("contact me to add new builtin accessors?")
        end
        and2(type_dispatch(ty), ret)
    end

    guard(pred, config) = (target, body) ->
      let cond = :($pred($target))
        :($cond ? $body : $failed)
      end
    
    effect(perf, config) = (target, body) ->
      Expr(:block, perf, body)

    (
        and = and,
        or = or,
        literal = literal,
        wildcard = wildcard,
        capture = capture,
        decons = decons,
        guard = guard,
        effect = effect,
    )
end
