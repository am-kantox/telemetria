defmodule Telemetria.Handler.Default do
  @moduledoc """
  Default handler used unless the custom one is specified in config.

  This handler collects `event`, `measurements`, `metadata`, and `config`,
  packs them into the keyword list and logs on `:info` log level.
  """

  alias Telemetria.Handler

  use Boundary, deps: [Handler], exports: []

  require Logger

  @behaviour Handler
  @doc false
  @impl Handler
  def handle_event(event, measurements, metadata, config) do
    [event: event, measurements: measurements, metadata: metadata, config: config]
    |> inspect()
    |> Logger.info()
  end
end
