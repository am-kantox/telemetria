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

  @spec t(ast, [atom()] | atom()) :: ast when ast: {atom(), keyword(), tuple()}
  defmacro t(ast, call \\ [])

  defmacro t({:fn, meta, clauses}, call) do
    clauses =
      for {:->, meta, [args, clause]} <- clauses do
        {:->, meta, [args, do_t(clause, call, __CALLER__)]}
      end

    {:fn, meta, clauses}
  end

  defmacro t(ast, call), do: do_t(ast, call, __CALLER__)

  @compile {:inline, do_t: 3}
  @spec do_t(ast, [atom()] | atom(), Macro.Env.t()) :: ast when ast: {atom(), keyword(), tuple()}
  defp do_t(ast, call, caller) do
    case telemetry_wrap(ast, List.wrap(call), caller) do
      [do: ast] -> ast
      ast -> ast
    end
  end

  @compile {:inline, telemetry_prefix: 2}

  @spec telemetry_prefix(Macro.Env.t(), {atom(), keyword(), tuple()} | nil) :: [atom()]
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

  @spec telemetry_wrap(any(), any(), Macro.Env.t()) :: any()
  defp telemetry_wrap(nil, call, %Macro.Env{} = caller) do
    report(telemetry_prefix(caller, call), caller)
    nil
  end

  defp telemetry_wrap(expr, call, %Macro.Env{} = caller) do
    {block, expr} =
      if Keyword.keyword?(expr) do
        Keyword.pop(expr, :do, [])
      else
        {expr, []}
      end

    event = telemetry_prefix(caller, call)

    report(event, caller)

    :telemetry.attach(
      Telemetria.Instrumenter.otp_app(),
      event,
      &Telemetria.Instrumenter.handle_event/4,
      nil
    )

    unless is_nil(caller.module),
      do: Module.put_attribute(caller.module, :doc, {caller.line, telemetry: true})

    caller = Macro.escape(caller)

    block =
      quote do
        reference = inspect(make_ref())

        now = System.monotonic_time(:microsecond)
        result = unquote(block)
        benchmark = System.monotonic_time(:microsecond) - now

        :telemetry.execute(
          unquote(event),
          %{
            reference: reference,
            system_time: System.system_time(),
            tc: benchmark
          },
          %{context: unquote(caller)}
        )

        result
      end

    Keyword.put(expr, :do, block)
  end

  defp report(event, caller) do
    Mix.shell().info([
      [:bright, :green, "[INFO] ", :reset],
      "Add event: #{inspect(event)} at ",
      "#{caller.file}:#{caller.line}"
    ])
  end
end
