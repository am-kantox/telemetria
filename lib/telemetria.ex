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

  @compile {:inline, telemetry_prefix: 1}

  @spec telemetry_prefix(module()) :: [atom()]
  defp telemetry_prefix(mod),
    do: mod |> Module.split() |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))

  defp telemetry_wrap(nil, _call, _caller), do: nil

  defp telemetry_wrap(expr, call, caller) do
    {block, expr} = Keyword.pop(expr, :do, [])

    {f, _, _} = call
    event = telemetry_prefix(caller.module) ++ [f]

    Mix.shell().info([
      [:bright, :green, "[INFO] ", :reset],
      "Add event: #{inspect(event)} at ",
      "#{caller.file}:#{caller.line}"
    ])

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
end
