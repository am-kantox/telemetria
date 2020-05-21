defmodule Telemetria.Instrumenter do
  @moduledoc false

  require Logger
  use Boundary, deps: [Telemetria.ConfigProvider], exports: []

  @json_config Telemetria.ConfigProvider.json_config!()

  @otp_app Application.get_env(:telemetria, :otp_app, [])
  @spec otp_app :: binary()
  def otp_app, do: to_string(Keyword.get(@json_config, :otp_app, @otp_app))

  @events Application.fetch_env!(:telemetria, :events)
  @spec events :: [[atom()]]
  def events, do: Enum.to_list(MapSet.new(Keyword.get(@json_config, :events, []) ++ @events))

  def setup do
    Application.stop(:telemetry)
    Application.start(:telemetry)
    :telemetry.attach_many(otp_app(), events(), &handle_event/4, nil)
  end

  def handle_event(event, measurements, context, config) do
    {m, f, 4} = Application.get_env(:telemetria, :handler, {Telemetria.Handler, :handle_event, 4})
    apply(m, f, [event, measurements, context, config])
  end
end
