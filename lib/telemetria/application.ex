defmodule Telemetria.Application do
  @moduledoc false

  use Elixir.Application

  @backend Application.compile_env(:telemetria, :backend, Telemetria.Backend.Logger)
  if @backend == Telemetria.Backend.Logger,
    do: IO.warn("No `:telemetria, :backend` config specified, falling back to `Logger`")

  @doc false
  def backend, do: @backend |> fix_name() |> List.wrap()

  defp fix_name(name) when is_atom(name) do
    name
    |> to_string()
    |> Module.split()
    |> case do
      ["Telemetria", "Backend", _ | _] ->
        name

      _ ->
        IO.warn(
          "Please prefer `Telemetria.Backend.YourBackend` naming for telemetría backends, got: ‹#{inspect(name)}›"
        )

        name
    end
  rescue
    _e in [ArgumentError] ->
      Telemetria.Backend |> Module.concat(name |> to_string() |> Macro.camelize()) |> fix_name()
  end

  @doc false
  def telemetry?, do: Telemetria.Backend.Telemetry in List.wrap(backend())

  @doc false
  def open_telemetry?, do: Telemetria.Backend.OpenTelemetry in List.wrap(backend())

  @impl Elixir.Application
  def start(_type, _args) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

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
  # credo:disable-for-lines:2 Credo.Check.Refactor.Apply
  def start_phase(:telemetry_setup, _start_type, []),
    do: if(telemetry?(), do: apply(Telemetria.Instrumenter, :setup, []), else: :ok)
end
