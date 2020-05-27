defmodule Telemetria.Instrumenter do
  @moduledoc false

  require Logger
  use Boundary, deps: [Telemetria.ConfigProvider], exports: []

  @spec json_config :: keyword()
  def json_config, do: Telemetria.ConfigProvider.json_config!()

  @spec otp_app :: binary()
  def otp_app,
    do:
      Keyword.get(
        json_config(),
        :otp_app,
        Application.get_env(:telemetria, :otp_app, :telemetria)
      )

  @spec events :: [[atom()]]
  def events,
    do:
      Enum.to_list(
        MapSet.new(
          Keyword.get(json_config(), :events, []) ++ Application.get_env(:telemetria, :events, [])
        )
      )

  def setup() do
    Application.ensure_all_started(:telemetry)
    :telemetry.attach_many(Atom.to_string(otp_app()), events(), &handle_event/4, nil)
  end

  def handle_event(event, measurements, context, config) do
    {m, f, 4} = Application.get_env(:telemetria, :handler, {Telemetria.Handler, :handle_event, 4})
    apply(m, f, [event, measurements, context, config])
  end
end
