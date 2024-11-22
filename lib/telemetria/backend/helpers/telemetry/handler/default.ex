defmodule Telemetria.Handler.Default do
  @moduledoc """
  Default handler used unless the custom one is specified in config.

  This handler collects `event`, `measurements`, `metadata`, and `config`,
  packs them into the keyword list and logs on `:info` log level.
  """

  alias Telemetria.Handler

  require Logger

  # credo:disable-for-next-line Credo.Check.Warning.ApplicationConfigInModuleAttribute
  @logger_formatter Application.get_all_env(:logger)
                    |> Enum.map(fn {_, v} ->
                      if Keyword.keyword?(v), do: v[:default_formatter] || v[:format]
                    end)
                    |> Enum.reject(&is_nil/1)
                    |> Enum.uniq()
                    |> Kernel.==([{Telemetria.Formatter, :format}])

  @default_process_info Application.compile_env(:telemetria, :process_info, false)

  @behaviour Handler
  @doc false
  @impl Handler
  def handle_event(event, measurements, metadata, config) do
    :telemetria
    |> Application.get_env(:smart_log, @logger_formatter)
    |> do_handle_event(event, measurements, metadata, config)
  end

  defmacrop maybe_log(severity, do: block) do
    quote do
      case Logger.compare_levels(
             unquote(severity),
             Application.get_env(:telemetria, :level, Logger.level())
           ) do
        :lt -> []
        _ -> unquote(block)
      end
    end
  end

  @spec do_handle_event(
          boolean(),
          Telemetria.event_name(),
          Telemetria.event_measurements(),
          Telemetria.event_metadata(),
          Telemetria.handler_config()
        ) :: :ok
  defp do_handle_event(true, event, measurements, metadata, config) do
    metadata = build_metadata(event, measurements, metadata, config)

    maybe_log metadata[:severity] do
      Logger.metadata(metadata[:metadata])
      do_log(metadata[:severity], metadata[:message], metadata[:env])
      Logger.reset_metadata(metadata[:default_metadata])
    end
  end

  defp do_handle_event(false, event, measurements, metadata, config) do
    metadata = build_metadata(event, measurements, metadata, config)

    maybe_log metadata[:severity] do
      do_log(
        metadata[:severity],
        inspect(metadata[:metadata], custom_options: [from: :telemetria]),
        metadata[:env]
      )
    end
  end

  @spec build_metadata(
          Telemetria.event_name(),
          Telemetria.event_measurements(),
          Telemetria.event_metadata(),
          Telemetria.handler_config()
        ) :: [{:severity, atom()}, {:metadata, keyword()}]
  defp build_metadata(event, measurements, metadata, config) do
    {options, metadata} = pop_in(metadata, [:context, :options])
    options = options || []
    {_context, metadata} = Map.pop(metadata, :context, [])
    {env, metadata} = Map.pop(metadata, :env, %{})

    env =
      {env[:module], env[:function]}
      |> case do
        {m, {f, a}} when not is_nil(m) -> Map.put(env, :function, Function.capture(m, f, a))
        _ -> env
      end
      |> Map.to_list()

    {severity, options} =
      Keyword.pop(options, :level, Application.get_env(:telemetria, :level, Logger.level()))

    {inspect_opts, options} = Keyword.pop(options, :inspect_opts, [])
    {message, options} = Keyword.pop(options, :message, "")
    {process_info?, options} = Keyword.pop(options, :process_info, @default_process_info)
    process_info = if process_info?, do: Telemetria.Handler.process_info(), else: []

    otp_app = Telemetria.otp_app()
    default_metadata = Logger.metadata()
    type = if match?([_, :vm | _], event), do: :stats, else: :metrics

    metadata =
      Keyword.merge(default_metadata,
        telemetría: [
          otp_app: otp_app,
          severity: severity,
          type: type,
          event: event,
          name: Enum.join(event, "."),
          inspect_opts: inspect_opts,
          config: config,
          context: options,
          measurements: measurements,
          call: metadata |> Map.to_list() |> Keyword.take([:args, :result, :locals])
        ],
        process_info: process_info
      )

    inspected_metadata = inspect(metadata, custom_options: [from: :telemetria])

    [
      severity: severity,
      message: message <> " → " <> inspected_metadata,
      default_metadata: default_metadata,
      env: env,
      metadata: metadata
    ]
  end

  @spec do_log(level :: Telemetria.Hooks.level(), message :: binary(), env :: Logger.metadata()) ::
          :ok
  if(Version.match?(System.version(), ">= 1.11.0-dev")) do
    @levels ~w|emergency alert critical error warning notice info debug|a
  else
    @levels ~w|error warn info debug|a
  end

  Enum.each(@levels, fn level ->
    defp do_log(unquote(level), message, env) when is_binary(message),
      do: Logger.unquote(level)(fn -> message end, env)
  end)

  defp do_log(:warn, message, env) when is_binary(message),
    do: Logger.warning(fn -> message end, env)

  defp do_log(level, message, env) when is_binary(message),
    do: Logger.warning(fn -> "[#{inspect(level)}] " <> message end, env)
end
