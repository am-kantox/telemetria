defmodule Telemetria.Handler do
  @moduledoc """
  The behaviour to be implemented by consumers.

  `Telemetría` provides the default handler, that simply delegates to `Logger.info/1`.

  _See:_ `Telemetria.Handler.Default`.
  """

  use Boundary, deps: [], exports: []

  @doc "The callback that will be invoked by `:telemetry`"
  @callback handle_event(
              :telemetry.event_name(),
              :telemetry.event_measurements(),
              :telemetry.event_metadata(),
              :telemetry.handler_config()
            ) :: :ok
end
