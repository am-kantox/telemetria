defmodule Telemetria.Instrumenter do
  @moduledoc false

  require Logger
  use Boundary, deps: [], exports: []

  @otp_app Application.fetch_env!(:telemetria, :otp_app)
  @spec otp_app :: binary()
  def otp_app, do: to_string(@otp_app)

  @events Application.fetch_env!(:telemetria, :events)
  @spec events :: [[atom()]]
  def events, do: @events

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
