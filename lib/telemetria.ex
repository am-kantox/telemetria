defmodule Telemetria do
  @moduledoc """
  `Telemetría` is the opinionated wrapper for [`:telemetry`](https://hexdocs.pm/telemetry)
  (started with `v0.19.0` it became agnostic to the actual telemetry backend and supports
  `OpenTelemetry` out of the box, allowing for more custom implementations of the said backend.)
  It provides handy macros to attach telemetry events to any function, private function,
  anonymous functions (on per-clause basis) and just random set of expressions.

  `Telemetría` exports three macros:

  - `deft/2` which is wrapping `Kernel.def/2`
  - `defpt/2` which is wrapping `Kernel.defp/2`
  - `t/2` which is wrapping the expression passed as the first parameter
    and adds the options passed as a keyword to the second parameter to the
    context of the respective telemetry event

  > ### Module attribute over macros {: .tip}
  >
  > Unless inevitably needed, one should prefer module attributes over explicit macros
  > (see the section “Using Module Attribute” below.)
  >
  > Module attributes have a way richer customization abilities, including but 
  > not limited to conditional wrapping, slack messaging etc. See options
  > which are accepted by the module attribute below.

  `Telemetría` allows compile-time telemetry events definition and provides
  a compiler that is responsible for incremental builds and updates of the list of
  events telemetry is aware about.

  > ### Compile-time config {: .warning}
  >
  > `Telemetría` uses a compiler to wrap annotated functions with a telemetry calls.
  > That means, that all the configuration must be placed into compile-time config files.

  ## Using Module Attribute

  Besides the functions listed above, one might attach `Telemetría` to the function
  by annotating it with `@telemetria` module attribute.

  There are several options to pass to this attribute:

  - **`true`** — attach the `telemetry` to the function
  - **`if: boolean()`** — compile-time condition
  - **`if: (result -> boolean())`** — runtime condition
  - **`level: Logger,level()`** — specify a min logger level to attach telemetry
  - **`group: atom()`** — the configured group to manage event throttling,
    see `:throttle` setting in `Telemetria.Options`
  - **`locals: [atom()]`** — the list of names of local variables to be exported
    to the telemetry call
  - **`transform: [{:args, (list() -> list())}, {:result, (any() -> any())}]`** — 
    the functions to be called on the incoming attributes and/or result to reshape them
  - **`reshape: (map() -> map())`** — the function to be called on the resulting attributes
    to reshape them before sending to the actual telemetry handler; the default application-wide
    reshaper might be set in `:telemetria, :reshaper` config
  - **`messenger_channels: %{optional(atom()) => {module, keyword()}`** — more handy messenger
    management, several channels config with channels names associated with their
    implementations and properties

  ### Example

  The following code would emit the telemetry event for the function `weather`,
    returning `result` in Celcius _and_ injecting `farenheit` value under `locals`

  ```elixir
  defmodule Forecast do
    use Telemetria

    @telemetria level: :info, group: :weather_reports, locals: [:farenheit]
    def weather(city) do
      fahrenheit = ExternalService.retrieve(city)
      Converter.fahrenheit_to_celcius(fahrenheit)
    end
  end
  ```

  ## Advantages

  `Telemetría` takes care about managing events in the target application,
  makes it a single-letter change to turn a function into a function wrapped
  with telemetry call, measuring the execution time out of the box.

  It also allows to easily convert expressions to be be telemetry-aware.

  Besides that, `telemetry: false` flag allows to purge the calls in compile-time
  resulting in zero overhead (useful for benchmark, or like.)

  ### Example

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

  ## Enabling `Telemetría`

  To enable `telemetría` for the project, you should add `:telemetria` compiler to the list
  of `Mix.compilers/0` as shown below (`mix.exs`).

  ```elixir
  def project do
    [
      ...
      compilers: [:telemetria | Mix.compilers()],
      ...
    ]
  end
  ```

  Additional steps are described below for the different use-cases.

  ### Plain Macros

  In the modules you want to add telemetry macros to, you should `require Telemetria` (or,
  preferably, `import Telemetria` to make it available without FQN.) Once imported,
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

  ### Module Attribute

  Module attributes are processed by the compilation hooks. To enable `@telemetria`
  module attributes, one should `use Telemetria`. Below is the example that would send
  two telemetry events to the configured `Telemetria.Backend`.

  ```elixir
  defmodule Otel do
    @moduledoc "`Telemetria` with :opentelemetry` example"

    use Telemetria

    @telemetria level: :info, group: :weather_reports, locals: [:celsius], messenger: :slack
    def f_to_c(fahrenheit) do
      celsius = do_f_to_c(fahrenheit)
      round(celsius)
    end

    @telemetria level: :info, group: :weather_reports
    defp do_f_to_c(fahrenheit), do: (fahrenheit - 32) * 5 / 9
  end
  ```

  ### Typical Config

  `Telemetría` requires an application-wide config to operate properly. Yes, I know
  having a config in a library is discouraged by the core team. Unfortunately, for the
  compiler to work properly, the static compile-time config is still required.

  After all, even if running many OTP applications on the same node, one would barely
  want to have a different telemetry config for them.

  ```elixir
  import Config

  config :telemetria,
    purge_level: :debug,
    level: :info,
    events: [
      [:tm, :f_to_c]
    ],
    throttle: %{some_group: {1_000, :last}}
  # create a slack app and put URL here
  # messenger_channels: %{slack: {:slack, url: ""}}
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

  ## Options

  #{NimbleOptions.docs(Telemetria.Options.schema())}
  """

  alias Telemetria.{Backend, Mix.Events}

  @type event_name :: [atom(), ...] | String.t()
  @type event_measurements :: map()
  @type event_metadata :: map()
  @type event_value :: number()
  @type event_prefix :: [atom()]
  @type handler_config :: term()

  @default_level Application.compile_env(:telemetria, :level, :info)
  @default_reshaper Application.compile_env(:telemetria, :reshaper)
  @messenger_channels Application.compile_env(:telemetria, :messenger_channels, %{})

  @doc false
  defmacro __using__(opts) do
    initial_ast =
      case Keyword.get(opts, :action, :none) do
        :require -> quote(location: :keep, generated: true, do: require(Telemetria))
        :import -> quote(location: :keep, generated: true, do: import(Telemetria))
        :none -> :ok
        unknown -> IO.puts("Ignored unknown value for :action option: " <> inspect(unknown))
      end

    quote location: :keep, generated: true do
      unquote(initial_ast)
      Module.register_attribute(__MODULE__, :telemetria, accumulate: false)
      Module.register_attribute(__MODULE__, :telemetria_hooks, accumulate: true)

      @on_definition Telemetria.Hooks
      @before_compile Telemetria.Hooks
    end
  end

  @doc "Declares a function with a telemetry attached, measuring execution time"
  defmacro deft(call, expr) do
    expr = telemetry_wrap(expr, call, __CALLER__)

    quote location: :keep, generated: true do
      Kernel.def(unquote(call), unquote(expr))
    end
  end

  @doc "Declares a private function with a telemetry attached, measuring execution time"
  defmacro defpt(call, expr) do
    expr = telemetry_wrap(expr, call, __CALLER__)

    quote location: :keep, generated: true do
      Kernel.defp(unquote(call), unquote(expr))
    end
  end

  @doc "Attaches telemetry to anonymous function (per clause,) or to expression(s)"
  defmacro t(ast, opts \\ [])

  defmacro t({:fn, meta, clauses}, opts) do
    clauses =
      for {:->, meta, [args, clause]} <- clauses do
        {:->, meta,
         [
           args,
           do_t(clause, Keyword.merge([arguments: extract_guards(args)], opts), __CALLER__)
         ]}
      end

    {:fn, meta, clauses}
  end

  defmacro t(ast, opts), do: do_t(ast, opts, __CALLER__)

  @compile {:inline, enabled?: 0, enabled?: 1}
  @spec enabled?(opts :: keyword()) :: boolean()
  defp enabled?(opts \\ []),
    do: Keyword.get(opts, :enabled, Application.get_env(:telemetria, :enabled, true))

  @compile {:inline, do_t: 3}
  @spec do_t(ast, keyword(), Macro.Env.t()) :: ast
        when ast: {atom(), keyword(), tuple() | list()}
  defp do_t(ast, opts, caller) do
    if enabled?(opts) do
      {suffix, opts} = Keyword.pop(opts, :suffix)

      ast
      |> telemetry_wrap(List.wrap(suffix), caller, opts)
      |> Keyword.get(:do, [])
    else
      ast
    end
  end

  @doc false
  @spec otp_app :: atom()
  def otp_app do
    Application.get_env(
      :telemetria,
      :otp_app,
      case :application.get_application(self()) do
        {:ok, otp_app} -> otp_app
        _ -> :unknown
      end
    )
  end

  @doc false
  @spec noop(any()) :: any()
  def noop(arg), do: arg

  @doc false
  @spec yes(any()) :: true
  def yes(_arg), do: true

  @spec telemetry_prefix(
          Macro.Env.t(),
          {atom(), keyword(), tuple()} | nil | maybe_improper_list()
        ) :: [atom()]
  def telemetry_prefix(%Macro.Env{module: mod, function: fun}, call) do
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

    Enum.dedup(prefix ++ suffix)
  end

  @spec telemetry_wrap(ast, nil | ast | maybe_improper_list(), Macro.Env.t(), [
          Telemetria.Hooks.option()
        ]) :: ast
        when ast: keyword() | {atom(), keyword(), any()}
  @doc false
  def telemetry_wrap(expr, call, caller, context \\ [])

  def telemetry_wrap(expr, {:when, _meta, [call, _guards]}, %Macro.Env{} = caller, context) do
    telemetry_wrap(expr, call, caller, context)
  end

  def telemetry_wrap(expr, call, %Macro.Env{} = caller, context) do
    find_name = fn
      {{:_, _, _}, _} -> nil
      {{_, _, na} = n, _} when na in [nil, []] -> n
      {{:=, _, [{_, _, na} = n, _]}, _} when na in [nil, []] -> n
      {{:=, _, [_, {_, _, na} = n]}, _} when na in [nil, []] -> n
      {any, idx} -> {:=, [], [{:"arg_#{idx}", [], Elixir}, any]}
    end

    args =
      case call do
        {fun, meta, args} when is_atom(fun) and is_list(meta) and is_list(args) -> args
        _ -> []
      end
      |> Enum.with_index()
      |> Enum.map(find_name)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn
        {:=, _, [{name, _, _}, var]} -> {name, var}
        {name, _, _} = var -> {name, var}
      end)

    if enabled?() do
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

      caller = caller |> Map.take(~w|module function file line|a) |> Macro.escape()

      fix_fun = fn
        nil ->
          &Telemetria.noop/1

        {mod, fun} ->
          Function.capture(mod, fun, 1)

        f when is_function(f, 1) ->
          f

        weird ->
          raise Telemetria.Error,
                "transform must be a tuple `{mod, fun}` or a function capture, #{inspect(weird)} given"
      end

      level = get_in(context, [:options, :level]) || @default_level

      group = get_in(context, [:options, :group])

      args_transform =
        context |> get_in([:options, :transform, :args]) |> fix_fun.() |> Macro.escape()

      result_transform =
        context |> get_in([:options, :transform, :result]) |> fix_fun.() |> Macro.escape()

      locals =
        context |> get_in([:options, :locals]) |> Kernel.||([])

      reshape =
        context |> get_in([:options, :reshape]) |> Kernel.||(@default_reshaper)

      messenger =
        context
        |> get_in([:options, :messenger])
        |> case do
          nil -> nil
          false -> false
          {mod, opts} -> {mod, Keyword.put_new(opts, :level, level)}
          channel -> get_channel_info(channel, level)
        end

      {clause_args, context} = Keyword.pop(context, :arguments, [])
      args = Keyword.merge(args, clause_args)

      conditional = Macro.escape(context[:conditional] || (&Telemetria.yes/1))

      block =
        quote location: :keep, generated: true do
          now = [
            system: System.system_time(),
            monotonic: System.monotonic_time(:nanosecond),
            unique_integer: :erlang.unique_integer([:monotonic]),
            utc: DateTime.utc_now()
          ]

          block_ctx = Backend.entry(unquote(event))

          result = unquote(block)

          if unquote(conditional).(result) do
            benchmark_ns = System.monotonic_time(:nanosecond) - now[:monotonic]
            benchmark = div(benchmark_ns, 1_000)

            attributes = %{
              env: unquote(caller),
              locals: Keyword.take(binding(), unquote(locals)),
              result: unquote(result_transform).(result),
              args: unquote(args_transform).(unquote(args)),
              context: unquote(context)
            }

            Backend.update(unquote(event), %{timestamp: now[:utc]})

            Telemetria.Throttler.execute(
              unquote(group),
              {unquote(event),
               %{system_time: now, consumed: benchmark, consumed_ns: benchmark_ns}, attributes,
               unquote(reshape), unquote(messenger), block_ctx}
            )

            Backend.exit(block_ctx)
          end

          result
        end

      Keyword.put(expr, :do, block)
    else
      expr
    end
  end

  @warn_missing_compiler Application.compile_env(:telemetria, :warn_missing_compiler, false)

  defp report(event, caller) do
    if is_nil(GenServer.whereis(Events)) do
      if @warn_missing_compiler do
        Mix.shell().warning([
          "Added event: #{inspect(event)} at #{caller.file}:#{caller.line}, ",
          "but `Telemetria` config won’t be updated. `",
          "Add `:telemetria` compiler to `compilers:` in your `mix.exs`!"
        ])
      end
    else
      Events.put(:event, {caller.module, event})
    end
  end

  defp variablize({:_, _, _}), do: {:_, :skipped}
  defp variablize({:{}, _, elems}), do: {:tuple, Enum.map(elems, &variablize/1)}
  defp variablize({:%{}, _, elems}), do: {:map, Enum.map(elems, &variablize/1)}
  defp variablize({var, _, _} = val), do: {var, val}

  defp get_channel_info(channel, level) do
    case Map.get(@messenger_channels, channel, {channel, []}) do
      {mod, opts} -> {mod, Keyword.put(opts, :level, level)}
      mod when is_atom(mod) -> {mod, level: level}
    end
  end

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
