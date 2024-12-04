defmodule Telemetria.Hooks do
  @moduledoc false

  @type ast_meta :: keyword()
  @type ast_tuple :: {atom(), ast_meta(), any()}

  @typedoc """
  ## Levels

  The supported levels, ordered by importance, are:
    * `:emergency` - when system is unusable, panics
    * `:alert` - for alerts, actions that must be taken immediately, ex. corrupted database
    * `:critical` - for critical conditions
    * `:error` - for errors
    * `:warn` | `:warning` - for warnings
    * `:notice` - for normal, but signifant, messages
    * `:info` - for information of any kind
    * `:debug` - for debug-related messages
  """
  if Version.match?(System.version(), ">= 1.11.0-dev") do
    @type level :: :emergency | :alert | :critical | :error | :warning | :notice | :info | :debug
  else
    @type level :: :error | :warn | :info | :debug
  end

  @typedoc false
  @type option :: {:level, level()} | {:inspect_opts, Inspect.Opts.t()} | {atom(), any()}
  @typedoc false
  @type annotation_type :: :none | :head | :clause
  @typedoc false
  @type info :: %{
          annotation_type: annotation_type(),
          env: Macro.Env.t(),
          kind: :def | :defp,
          fun: atom(),
          arity: arity(),
          args: [ast_tuple()],
          guards: [ast_tuple()],
          body: [{:do, ast_tuple()}],
          conditional: (any() -> boolean()) | nil,
          options: [option()]
        }
  defstruct ~w|annotation_type env kind fun arity args guards body conditional options|a

  @default_level Application.compile_env(:telemetria, :level, Logger.level())
  @strict Application.compile_env(:telemetria, :strict, false)

  purge_level =
    get_in(Application.compile_env(:logger, :compile_time_purge_matching), [:level_lower_than]) ||
      Logger.level()

  purge_level =
    if purge_level == :warn and Version.match?(System.version(), ">= 1.11.0-dev"),
      do: :warning,
      else: purge_level

  @purge_level Application.compile_env(:telemetria, :purge_level, purge_level)

  def __on_definition__(env, kind, fun, args, guards, body) do
    case {Module.get_attribute(env.module, :telemetria), kind, body} do
      {options, kind, body} when kind in [:def, :defp] ->
        {type, {conditional, options}} = pop_apply(options, body)

        Module.put_attribute(
          env.module,
          :telemetria_hooks,
          struct(__MODULE__,
            annotation_type: type,
            env: env,
            kind: kind,
            fun: fun,
            arity: length(args),
            args: args,
            guards: guards,
            body: body,
            conditional: conditional,
            options: options
          )
        )

        Module.delete_attribute(env.module, :telemetria)

      {nil, _kind, _body} ->
        :ok

      {options, _kind, _body} when not is_nil(options) ->
        raise Telemetria.Error,
              "only function annotating is currently supported, please remove #{inspect(options)}"
    end
  end

  defmacro __before_compile__(env) do
    hooks =
      env.module
      |> Module.get_attribute(:telemetria_hooks)
      |> Enum.reverse()
      |> fix_hooks()

    overrides =
      hooks
      |> Enum.map(&{&1.fun, length(&1.args)})
      |> Enum.uniq()

    clauses =
      hooks
      |> Enum.map(fn info ->
        meta = info.env

        head =
          maybe_guarded(
            info.guards,
            info.fun,
            [module: meta.module, function: meta.function, file: meta.file, line: meta.line],
            info.args
          )

        body =
          Telemetria.telemetry_wrap(info.body, {info.fun, [line: meta.line], info.args}, meta,
            options: info.options,
            conditional: info.conditional
          )

        {info.kind, [context: Elixir, import: Kernel], [head, body]}
      end)

    [{:defoverridable, [context: Elixir, import: Kernel], [overrides]} | clauses]
  end

  @spec maybe_guarded([ast_tuple()], atom(), keyword(), [ast_tuple()]) :: ast_tuple()
  defp maybe_guarded([], f, meta, args),
    do: {f, meta, args}

  defp maybe_guarded(guards, f, meta, args) when is_list(guards),
    do: {:when, [context: Elixir], [{f, meta, args} | guards]}

  @spec pop_apply([{:if, boolean()} | option()] | boolean() | nil, Macro.t()) ::
          {annotation_type(), {(any() -> boolean()) | nil, [option()]}} | no_return()
  defp pop_apply(nil, body), do: pop_apply(false, body)
  defp pop_apply(false, body), do: pop_apply([if: false], body)
  defp pop_apply(true, body), do: pop_apply([if: true], body)

  defp pop_apply(options, body) do
    options
    |> Keyword.put_new(:level, @default_level)
    |> Keyword.pop(:if, not @strict)
    |> case do
      {false, options} ->
        {:none, {nil, options}}

      {true_or_fun, options} when true_or_fun == true or is_function(true_or_fun, 1) ->
        allow? =
          options
          |> Keyword.fetch!(:level)
          |> Logger.compare_levels(@purge_level)

        result = if true_or_fun == true, do: {nil, options}, else: {true_or_fun, options}

        case {allow?, body} do
          {:lt, _} -> {:none, result}
          {_, nil} -> {:head, result}
          {_, _} -> {:clause, result}
        end

      {weird, _options} ->
        raise Telemetria.Error, "unsupported `if` value " <> inspect(weird)
    end
  end

  @spec fix_hooks([info()]) :: [info()]
  defp fix_hooks(hooks) do
    hooks
    |> Enum.group_by(&{&1.fun, &1.arity})
    |> Enum.flat_map(fn {{_fun, _arity}, hooks} ->
      hooks
      |> Enum.map(& &1.annotation_type)
      |> Enum.uniq()
      |> Enum.sort()
      |> case do
        [:head, :none] ->
          [head | nones] = hooks
          Enum.map(nones, &%__MODULE__{&1 | annotation_type: :clause, options: head.options})

        [:head | _] ->
          raise Telemetria.Error, "one cannot define both head and per-clause attributes"

        [:clause] ->
          hooks

        [_] ->
          []

        _ ->
          raise Telemetria.Error, "either a head clause, or all clauses, or none could be handled"
      end
    end)
  end

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    def inspect(hook, opts) do
      args = hook.args |> Macro.to_string() |> String.slice(1..-2//1)

      guards =
        hook.guards
        |> Macro.to_string()
        |> String.slice(1..-2//1)
        |> case do
          "" -> ""
          other -> " when " <> other
        end

      doc = [
        annotation_type: hook.annotation_type,
        fun: "#{hook.kind} #{hook.env.module}.#{hook.fun}(#{args})#{guards}",
        location: [file: hook.env.file, line: hook.env.line],
        arity: hook.arity,
        body: not is_nil(hook.body),
        options: hook.options
      ]

      concat(["#Telemetria<", to_doc(doc, opts), ">"])
    end
  end
end
