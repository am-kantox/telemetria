defmodule Telemetria.Handler.Default do
  @moduledoc """
  Default handler used unless the custom one is specified in config.

  This handler collects `event`, `measurements`, `metadata`, and `config`,
  packs them into the keyword list and logs on `:info` log level.
  """

  alias Telemetria.Handler

  use Boundary, deps: [Handler], exports: []

  require Logger

  @logger_formatter Application.get_all_env(:logger)
                    |> Enum.map(fn {_, v} -> if Keyword.keyword?(v), do: v[:format] end)
                    |> Enum.reject(&is_nil/1)
                    |> Enum.uniq()
                    |> Kernel.==([{Telemetria.Formatter, :format}])

  @behaviour Handler
  @doc false
  @impl Handler
  def handle_event(event, measurements, metadata, config) do
    :telemetria
    |> Application.get_env(:smart_log, @logger_formatter)
    |> do_handle_event(event, measurements, metadata, config)
  end

  @spec do_handle_event(
          boolean(),
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: :ok
  defp do_handle_event(true, event, measurements, metadata, config) do
    metadata = build_metadata(event, measurements, metadata, config)
    Logger.metadata(metadata[:metadata])
    do_log(metadata[:severity], metadata[:message])
  end

  defp do_handle_event(false, event, measurements, metadata, config) do
    metadata = build_metadata(event, measurements, metadata, config)
    do_log(metadata[:severity], inspect(metadata[:metadata]))
  end

  @spec build_metadata(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: [{:severity, atom()}, {:metadata, keyword()}]
  defp build_metadata(event, measurements, metadata, config) do
    {inspect_opts, metadata} = Map.pop(metadata, :inspect, [])
    {options, metadata} = pop_in(metadata, [:context, :options])
    {context, metadata} = Map.pop(metadata, :context, [])

    otp_app =
      Application.get_env(
        :telemetria,
        :otp_app,
        case :application.get_application(self()) do
          {:ok, otp_app} -> otp_app
          _ -> :unknown
        end
      )

    message = Keyword.get(options || [], :message, "")
    severity = Keyword.get(options || [], :level, Application.get_env(:telemetria, :level, :info))

    [
      severity: severity,
      message: message,
      metadata:
        Keyword.merge(Logger.metadata(),
          __meta__: [
            otp_app: otp_app,
            severity: severity,
            type: :metrics,
            name: event,
            inspect_opts: inspect_opts,
            context: context
          ],
          __measurements__: measurements,
          __rest__: Map.to_list(metadata),
          config: config
        )
    ]
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
