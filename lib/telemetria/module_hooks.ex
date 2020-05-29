defmodule Telemetria.Hooks do
  @moduledoc false

  @type ast_meta :: keyword()
  @type ast_tuple :: {atom(), ast_meta(), any()}
  @type definition ::
          {:env, Macro.Env.t()}
          | {:kind, :def | :defp}
          | {:fun, atom()}
          | {:args, [ast_tuple()]}
          | {:guards, [ast_tuple()]}
          | {:body, [{:do, ast_tuple()}]}
  @type definitions :: [definition()]

  def __on_definition__(env, kind, fun, args, guards, body) do
    case {Module.get_attribute(env.module, :telemetria), kind, body} do
      {nil, _, _} ->
        :ok

      {true, kind, body} when kind in [:def, :defp] and not is_nil(body) ->
        Module.put_attribute(env.module, :telemetria_hooks,
          env: env,
          kind: kind,
          fun: fun,
          args: args,
          guards: guards,
          body: body
        )

        Module.delete_attribute(env.module, :telemetria)

      {true, _, nil} ->
        raise Telemetria.Error, "only functions with body can be currently annotated"

      {true, _, _} ->
        raise Telemetria.Error, "only function annotating is currently supported"

      {other, _, _} ->
        raise Telemetria.Error, "inline handlers are not yet supported, #{inspect(other)} given"
    end
  end

  defmacro __before_compile__(env) do
    env.module
    |> Module.get_attribute(:telemetria_hooks)
    |> Enum.flat_map(fn df ->
      meta = df[:env]
      head = maybe_guarded(df[:guards], df[:fun], [file: meta.file, line: meta.line], df[:args])
      body = Telemetria.telemetry_wrap(df[:body], nil, meta)

      [
        {:defoverridable, [context: Elixir, import: Kernel], [[{df[:fun], length(df[:args])}]]},
        {df[:kind], [context: Elixir, import: Kernel], [head, body]}
      ]
    end)
  end

  @spec maybe_guarded([ast_tuple()], atom(), keyword(), [ast_tuple()]) :: ast_tuple()
  defp maybe_guarded([], f, meta, args),
    do: {f, meta, args}

  defp maybe_guarded(guards, f, meta, args) when is_list(guards),
    do: {:when, [context: Elixir], [{f, meta, args} | guards]}
end
