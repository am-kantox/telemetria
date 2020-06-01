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
    {inspect_opts, metadata} = Map.pop(metadata, :inspect, [])
    {level, metadata} = pop_in(metadata, [:context, :level])
    {result, metadata} = Map.pop(metadata, :result, :unknown)

    level =
      if is_nil(level),
        do: Application.get_env(:telemetria, :level, :info),
        else: level

    inspected =
      inspect(
        [
          event: event,
          measurements: measurements,
          result: result,
          metadata: metadata,
          config: config
        ],
        inspect_opts
      )

    do_log(level, inspected)
  end

  @spec do_log(level :: Telemetria.Hooks.level(), message :: binary()) :: :ok
  if(Version.match?(System.version(), ">= 1.11.0-dev")) do
    @levels ~w|emergency alert critical error warn notice info debug|a
  else
    @levels ~w|error warn info debug|a
  end

  Enum.each(@levels, fn level ->
    defp do_log(unquote(level), message) when is_binary(message),
      do: Logger.unquote(level)(fn -> message end)
  end)

  defp do_log(level, message) when is_binary(message),
    do: Logger.warn(fn -> "[#{inspect(level)}] " <> message end)
end
