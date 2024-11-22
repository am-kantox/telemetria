defmodule Telemetria.Application do
  @moduledoc false

  use Elixir.Application

  @backend Application.compile_env(:telemetria, :backend, Telemetria.Backend.Telemetry)

  @doc false
  def backend, do: @backend

  @doc false
  def telemetry?, do: Telemetria.Backend.Telemetry in List.wrap(backend())

  @doc false
  def open_telemetry?, do: Telemetria.Backend.OpenTelemetry in List.wrap(backend())

  @impl Elixir.Application
  def start(_type, _args) do
    if telemetry?(), do: Application.ensure_all_started(:telemetry)
    Application.put_all_env(telemetria: Telemetria.Options.initial())

    opts = [strategy: :rest_for_one, name: Telemetria]

    throttler_args =
      :telemetria
      |> Application.fetch_env!(:throttle)
      |> case do
        :none -> %{}
        {interval, kind} -> %{default: {interval, kind}}
        %{} = map -> map
      end
      |> Map.put_new(:default, {0, :none})

    children = if telemetry?(), do: [Telemetria.Telemetry], else: []
    children = children ++ [{Telemetria.Throttler, throttler_args}]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def start_phase(:telemetry_setup, _start_type, []),
    do: if(telemetry?(), do: Telemetria.Instrumenter.setup(), else: :ok)
end
