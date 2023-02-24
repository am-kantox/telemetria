defmodule Telemetria.Instrumenter do
  @moduledoc false

  alias Telemetria.{ConfigProvider, Handler}

  use Boundary, deps: [ConfigProvider, Handler], exports: []

  require Logger

  @behaviour Handler

  @spec setup :: :ok | {:error, :already_exists}
  def setup do
    :telemetry.attach_many(
      Atom.to_string(otp_app()),
      events(),
      &Telemetria.Instrumenter.handle_event/4,
      buffer()
    )
  end

  @spec json_config :: keyword()
  def json_config, do: ConfigProvider.json_config!()

  @spec otp_app :: atom()
  def otp_app,
    do:
      Keyword.get(
        json_config(),
        :otp_app,
        Application.get_env(:telemetria, :otp_app, :telemetria)
      )

  @spec polling? :: boolean()
  def polling?,
    do:
      get_in(json_config(), [:polling, :enabled]) ||
        Application.get_env(:telemetria, :polling)[:enabled]

  @spec events :: [[atom()]]
  def events do
    json_config()
    |> Keyword.get(:events, [])
    |> Kernel.++(poller_events(polling?()))
    |> Kernel.++(Application.get_env(:telemetria, :events, []))
    |> MapSet.new()
    |> Enum.to_list()
  end

  @spec buffer :: pid() | nil
  @doc false
  def buffer, do: Process.whereis(Telemetria.Buffer)

  @impl Telemetria.Handler
  def handle_event(event, measurements, context, config) do
    {m, f} =
      Application.get_env(:telemetria, :handler, {Telemetria.Handler.Default, :handle_event})

    apply(m, f, [event, measurements, context, config])
  end

  @spec poller_events(boolean()) :: [[atom()]]
  defp poller_events(true) do
    otp_app = otp_app()
    [[otp_app, :vm, :system_info], [otp_app, :vm, :process_info]]
  end

  defp poller_events(_), do: []
end
