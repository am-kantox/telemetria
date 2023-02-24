defmodule Telemetria.Application do
  @moduledoc false

  use Elixir.Application

  @impl Elixir.Application
  def start(_type, _args) do
    Application.ensure_all_started(:telemetry)
    Application.put_all_env(telemetria: Telemetria.Options.initial())

    opts = [strategy: :rest_for_one, name: Telemetria]

    io_args =
      if Version.match?(System.version(), ">= 1.15.0-dev"), do: {self(), "", []}, else: {"", []}

    children = [
      %{
        id: Telemetria.Buffer,
        start: {GenServer, :start_link, [StringIO, io_args, [name: Telemetria.Buffer]]}
      },
      {Telemetria.Polling, Application.get_env(:telemetria, :polling, [])}
    ]

    Supervisor.start_link(children, opts)
  end

  @impl Application
  def start_phase(:telemetry_setup, _start_type, []),
    do: Telemetria.Instrumenter.setup()
end
