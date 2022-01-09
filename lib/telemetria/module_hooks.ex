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
    * `:warn` - for warnings
    * `:notice` - for normal, but signifant, messages
    * `:info` - for information of any kind
    * `:debug` - for debug-related messages
  """
  if Version.match?(System.version(), ">= 1.11.0-dev") do
    @type level :: :emergency | :alert | :critical | :error | :warn | :notice | :info | :debug
  else
    @type level :: :error | :warn | :info | :debug
  end

  @typedoc false
  @type option :: {:level, level()} | {:inspect_opts, Inspect.Opts.t()} | {atom(), any()}
  @typedoc false
  @type info :: %{
          env: Macro.Env.t(),
          kind: :def | :defp,
          fun: atom(),
          args: [ast_tuple()],
          guards: [ast_tuple()],
          body: [{:do, ast_tuple()}],
          options: [option()]
        }
  defstruct ~w|env kind fun args guards body options|a

  def __on_definition__(env, kind, fun, args, guards, body) do
    case {Module.get_attribute(env.module, :telemetria), kind, body} do
      {nil, _, _} ->
        :ok

      {_, _, nil} ->
        raise Telemetria.Error, "only functions with body can be currently annotated"

      {_, kind, _} when kind not in [:def, :defp] ->
        raise Telemetria.Error, "only function annotating is currently supported"

      {options, kind, body} when is_list(options) or options == true ->
        options = if options == true, do: [], else: options

        Module.put_attribute(
          env.module,
          :telemetria_hooks,
          struct(__MODULE__,
            env: env,
            kind: kind,
            fun: fun,
            args: args,
            guards: guards,
            body: body,
            options: options
          )
        )

        Module.delete_attribute(env.module, :telemetria)

      {other, _, _} ->
        raise Telemetria.Error, "inline handlers are not yet supported, #{inspect(other)} given"
    end
  end

  defmacro __before_compile__(env) do
    hooks =
      env.module
      |> Module.get_attribute(:telemetria_hooks)
      |> Enum.reverse()

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
            options: info.options
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
end
