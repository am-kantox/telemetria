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

  defmacro deft(call, expr),
    do: define(:def, call, telemetry_wrap(expr, call, __CALLER__), __CALLER__)

  defmacro defpt(call, expr),
    do: define(:defp, call, telemetry_wrap(expr, call, __CALLER__), __CALLER__)

  defmacro defmacrot(call, expr),
    do: define(:defmacro, call, telemetry_wrap(expr, call, __CALLER__), __CALLER__)

  defmacro defmacropt(call, expr),
    do: define(:defmacrop, call, telemetry_wrap(expr, call, __CALLER__), __CALLER__)

  @compile {:inline, telemetry_prefix: 1}

  @spec telemetry_prefix(module()) :: [atom()]
  defp telemetry_prefix(mod),
    do: mod |> Module.split() |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))

  defp telemetry_wrap(nil, _call, _caller), do: nil

  defp telemetry_wrap(expr, call, caller) do
    {block, expr} = Keyword.pop(expr, :do, [])

    {f, _, _} = call
    event = telemetry_prefix(caller.module) ++ [f]

    :telemetry.attach(
      Telemetria.Instrumenter.otp_app(),
      event,
      &Telemetria.Instrumenter.handle_event/4,
      nil
    )

    Module.put_attribute(caller.module, :doc, {caller.line, telemetry: true})
    caller = Macro.escape(caller)

    block =
      quote do
        reference = inspect(make_ref())

        now = System.monotonic_time(:microsecond)
        result = unquote(block)
        benchmark = System.monotonic_time(:microsecond) - now

        :telemetry.execute(
          unquote(event),
          %{system_time: System.system_time(), tc: benchmark},
          %{context: unquote(caller)}
        )

        result
      end

    Keyword.put(expr, :do, block)
  end

  defp define(kind, call, expr, env) do
    module = assert_module_scope(env, kind, 2)
    assert_no_function_scope(env, kind, 2)

    unquoted_call = :elixir_quote.has_unquotes(call)
    unquoted_expr = :elixir_quote.has_unquotes(expr)
    escaped_call = :elixir_quote.escape(call, :default, true)

    escaped_expr =
      case unquoted_expr do
        true ->
          :elixir_quote.escape(expr, :default, true)

        false ->
          key = :erlang.unique_integer()
          :elixir_module.write_cache(module, key, expr)
          quote(do: :elixir_module.read_cache(unquote(module), unquote(key)))
      end

    # Do not check clauses if any expression was unquoted
    check_clauses = not (unquoted_expr or unquoted_call)
    pos = :elixir_locals.cache_env(env)

    quote do
      :elixir_def.store_definition(
        unquote(kind),
        unquote(check_clauses),
        unquote(escaped_call),
        unquote(escaped_expr),
        unquote(pos)
      )
    end
  end

  defp assert_module_scope(env, fun, arity) do
    case env.module do
      nil -> raise ArgumentError, "cannot invoke #{fun}/#{arity} outside module"
      mod -> mod
    end
  end

  defp assert_no_function_scope(env, fun, arity) do
    case env.function do
      nil -> :ok
      _ -> raise ArgumentError, "cannot invoke #{fun}/#{arity} inside function/macro"
    end
  end
end
