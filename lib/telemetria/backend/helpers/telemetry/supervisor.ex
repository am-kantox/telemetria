defmodule Telemetria.Telemetry do
  @moduledoc """
  The `Supervisor` managing all the internal bundled `telemetry` helpers.
  """
  use Supervisor

  @spec start_link(polling_opts :: keyword()) :: Supervisor.on_start()
  @doc "Starts this supervisor linked"
  def start_link(polling_opts \\ []) do
    Supervisor.start_link(__MODULE__, polling_opts, name: __MODULE__)
  end

  @impl Supervisor
  @doc false
  def init(polling_opts) do
    io_args =
      if Version.match?(System.version(), ">= 1.15.0-dev"), do: {self(), "", []}, else: {"", []}

    children =
      [
        %{
          id: Telemetria.Buffer,
          start: {GenServer, :start_link, [StringIO, io_args, [name: Telemetria.Buffer]]}
        },
        {Telemetria.Polling, Application.get_env(:telemetria, :polling, polling_opts)}
      ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
