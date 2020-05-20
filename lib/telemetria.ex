defmodule Telemetria do
  @moduledoc """
  Declares helpers to define functions with telemetria attached.
  """

  use Boundary, deps: [Telemetria.Instrumenter], exports: []

  defmodule Handler do
    @moduledoc "Default handler used unless the custom one is specified in config"

    require Logger
    use Boundary, deps: [], exports: []

    @doc false
    def handle_event(event, measurements, metadata, config) do
      [event: event, measurements: measurements, metadata: metadata, config: config]
      |> inspect()
      |> Logger.warn()
    end
  end

  defmacro deft(call, expr) do
    expr = telemetry_wrap(expr, call, __CALLER__)

    quote do
      Kernel.def(unquote(call), unquote(expr))
    end
  end

  defmacro defpt(call, expr) do
    expr = telemetry_wrap(expr, call, __CALLER__)

    quote do
      Kernel.defp(unquote(call), unquote(expr))
    end
  end

  defmacro t(ast, call \\ [])

  defmacro t({:fn, meta, clauses}, call) do
    clauses =
      for {:->, meta, [args, clause]} <- clauses do
        {:->, meta, [args, do_t(clause, call, __CALLER__, arguments: extract_guards(args))]}
      end

    {:fn, meta, clauses}
  end

  defmacro t(ast, call), do: do_t(ast, call, __CALLER__)

  @compile {:inline, do_t: 3, do_t: 4}
  @spec do_t(ast, [atom()] | atom(), Macro.Env.t(), keyword()) :: ast
        when ast: {atom(), keyword(), tuple() | list()}
  defp do_t(ast, call, caller, context \\ []) do
    ast
    |> telemetry_wrap(List.wrap(call), caller, context)
    |> Keyword.get(:do, [])
  end

  @compile {:inline, telemetry_prefix: 2}
  @spec telemetry_prefix(
          Macro.Env.t(),
          {atom(), keyword(), tuple()} | nil | maybe_improper_list()
        ) :: [atom()]
  defp telemetry_prefix(%Macro.Env{module: mod, function: fun}, call) do
    suffix =
      case fun do
        {f, _arity} -> [f]
        _ -> []
      end ++
        case call do
          [_ | _] = suffices -> suffices
          {f, _, _} when is_atom(f) -> [f]
          _ -> []
        end

    prefix =
      case mod do
        nil ->
          [:module_scope]

        mod when is_atom(mod) ->
          mod |> Module.split() |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
      end

    prefix ++ suffix
  end

  @spec telemetry_wrap(ast, maybe_improper_list(), Macro.Env.t(), keyword()) :: ast
        when ast: keyword() | {atom(), keyword(), tuple() | list()}
  defp telemetry_wrap(expr, call, %Macro.Env{} = caller, context \\ []) do
    {block, expr} =
      if Keyword.keyword?(expr) do
        Keyword.pop(expr, :do, [])
      else
        {expr, []}
      end

    event = telemetry_prefix(caller, call)

    report(event, caller)

    unless is_nil(caller.module),
      do: Module.put_attribute(caller.module, :doc, {caller.line, telemetry: true})

    caller = Macro.escape(caller)

    block =
      quote do
        reference = inspect(make_ref())

        now = [
          system: System.system_time(),
          monotonic: System.monotonic_time(:microsecond),
          utc: DateTime.utc_now()
        ]

        result = unquote(block)
        benchmark = System.monotonic_time(:microsecond) - now[:monotonic]

        :telemetry.execute(
          unquote(event),
          %{
            reference: reference,
            system_time: now,
            consumed: benchmark
          },
          %{env: unquote(caller), context: unquote(context)}
        )

        result
      end

    Keyword.put(expr, :do, block)
  end

  defp report(event, caller) do
    if is_nil(GenServer.whereis(Telemetria.Mix.Events)) do
      Mix.shell().info([
        [:bright, :green, "[INFO] ", :reset],
        "Added event: #{inspect(event)} at ",
        "#{caller.file}:#{caller.line}"
      ])

      Mix.shell().info([
        [:bright, :yellow, "[WARN] ", :reset],
        "Telemetria config won’t be updated! ",
        "Add `:telemetria` compiler to `compilers:` in your `mix.exs`!"
      ])
    else
      Telemetria.Mix.Events.put(:event, {caller.module, event})
    end
  end

  defp variablize({:_, _, _}), do: {:_, :skipped}
  defp variablize({:{}, _, elems}), do: {:tuple, Enum.map(elems, &variablize/1)}
  defp variablize({:%{}, _, elems}), do: {:map, Enum.map(elems, &variablize/1)}
  defp variablize({var, _, _} = val), do: {var, val}

  defp extract_guards([]), do: []

  defp extract_guards([_ | _] = list) do
    list
    |> Enum.map(&extract_guards/1)
    |> Enum.map(fn
      {:_, _, _} = underscore -> variablize(underscore)
      {{op, _, _} = term, _guards} when op in [:{}, :%{}] -> variablize(term)
      {{_, _, _} = val, _guards} -> variablize(val)
      {_, _, _} = val -> variablize(val)
      other -> {:unknown, inspect(other)}
    end)
  end

  defp extract_guards({:when, _, [l, r]}), do: {l, extract_or_guards(r)}
  defp extract_guards(other), do: {other, []}

  defp extract_or_guards({:when, _, [l, r]}), do: [l | extract_or_guards(r)]
  defp extract_or_guards(other), do: [other]
end
