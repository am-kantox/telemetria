defmodule Telemetria do
  @moduledoc """
  `Telemetría` is the opinionated wrapper for [`:telemetry`](https://hexdocs.pm/telemetry)
  providing handy macroses to attach telemetry events to any function, private function,
  anonymous functions (on per-clause basis) and just random set of expressions.

  `Telemetría` exports three macroses:

  - `deft/2` which is wrapping `Kernel.def/2`
  - `defpt/2` which is wrapping `Kernel.defp/2`
  - `t/2` which is wrapping the expression passed as the first parameter
    and adds the options passed as a keyword to the second parameter to the
    context of the respective telemetry event

  `Telemetría` allows compile-time telemetry events definition and provides
  a compiler that is responsible for incremental builds and updates of the list of
  events telemetry is sware about.

  ## Advantages

  `Telemetría` takes care about managing events in the target application,
  makes it a single-letter change to turn a function into a function wrapped
  with telemetry call, measuring the execution time out of the box.

  It also allows to easily convert expressions to be be telemetry-aware.

  Besides that, `telemetry: false` flag allows to purge the calls in compile-time
  resulting in zero overhead (useful for benchmark, or like.)

  ## Example

  You need to include the compiler in `mix.exs`:

  ```elixir
  defmodule MyApp.MixProject do
    def project do
      [
        # ...
        compilers: [:telemetria | Mix.compilers()],
        # ...
      ]
    end
    # ...
  end
  ```

  In the modules you want to add telemetry to, you should `require Telemetria` (or,
  preferrably, `import Telemetria` to make it available without FQN.) Once imported,
  the macros are available and tracked by the compiler.

  ```elixir
  defmodule MyMod do
    import Telemetria

    defpt pi, do: 3.14
    deft answer, do: 42 - pi()

    def inner do
      short_result = t(42 * 42)
      result =
        t do
          # long calculations
          :ok
        end
    end
  end
  ```

  ## Use in releases

  `:telemetria` compiler keeps track of the events in the compiler manifest file
  to support incremental builds. Also it spits out `config/.telemetria.config.json`
  config for convenience. It might be used in in the release configuration as shown below.

  ```elixir
  releases: [
    configured: [
      # ...,
      config_providers: [{Telemetria.ConfigProvider, "/etc/telemetria.json"}]
    ]
  ]
  ```
  """

  use Boundary, deps: [Telemetria.Instrumenter, Telemetria.Mix.Events], exports: []

  alias Telemetria.Mix.Events

  defmodule Handler do
    @moduledoc """
    Default handler used unless the custom one is specified in config.

    This handler collects `event`, `measurements`, `metadata`, and `config`,
    packs them into the keyword list and logs on `:info` log level.
    """

    require Logger
    use Boundary, deps: [], exports: []

    @doc false
    def handle_event(event, measurements, metadata, config) do
      [event: event, measurements: measurements, metadata: metadata, config: config]
      |> inspect()
      |> Logger.info()
    end
  end

  @doc "Declares a function with a telemetry attached, neasuring execution time"
  defmacro deft(call, expr) do
    expr = telemetry_wrap(expr, call, __CALLER__)

    quote do
      Kernel.def(unquote(call), unquote(expr))
    end
  end

  @doc "Declares a private function with a telemetry attached, neasuring execution time"
  defmacro defpt(call, expr) do
    expr = telemetry_wrap(expr, call, __CALLER__)

    quote do
      Kernel.defp(unquote(call), unquote(expr))
    end
  end

  @doc "Attaches telemetry to anonymous function (per clause,) or to expression(s)"
  defmacro t(ast, opts \\ [])

  defmacro t({:fn, meta, clauses}, opts) do
    clauses =
      for {:->, meta, [args, clause]} <- clauses do
        {:->, meta,
         [args, do_t(clause, Keyword.merge([arguments: extract_guards(args)], opts), __CALLER__)]}
      end

    {:fn, meta, clauses}
  end

  defmacro t(ast, opts), do: do_t(ast, opts, __CALLER__)

  @compile {:inline, do_t: 3}
  @spec do_t(ast, keyword(), Macro.Env.t()) :: ast
        when ast: {atom(), keyword(), tuple() | list()}
  defp do_t(ast, opts, caller) do
    {suffix, opts} = Keyword.pop(opts, :suffix)

    ast
    |> telemetry_wrap(List.wrap(suffix), caller, opts)
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
    if is_nil(GenServer.whereis(Events)) do
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
      Events.put(:event, {caller.module, event})
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
