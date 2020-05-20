defmodule Mix.Tasks.Compile.Telemetria do
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Boundary, deps: [], exports: []
  use Mix.Task.Compiler
  alias Mix.Task.Compiler
  alias Telemetria.Mix.Events

  @preferred_cli_env :dev

  @moduledoc """
  Allows compile-time telemetry events definition.

  ## Usage

  You need to include the compiler in `mix.exs`:

  ```
  defmodule MySystem.MixProject do
    # ...

    def project do
      [
        compilers: [:telemetria] ++ Mix.compilers(),
        # ...
      ]
    end

    # ...
  end
  ```
  """

  @impl Compiler
  def run(argv) do
    :ok = Application.ensure_started(:telemetry)
    Events.start_link()

    Compiler.after_compiler(:app, &after_compiler(&1, argv))

    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [__MODULE__ | tracers])

    {:ok, [diagnostic("hey there")]}
  end

  @manifest_events "telemetria_events"

  @impl Compiler
  def manifests, do: [manifest_path(@manifest_events)]

  @impl Compiler
  def clean do
    :ok
  end

  @doc false
  # def trace({remote, _meta, Telemetria, _name, _arity}, _env)
  def trace({remote, meta, Telemetria, _name, _arity}, env)
      when remote in ~w/remote_macro imported_macro/a do
    Events.put(:module, {env.module, meta})
    :ok
  end

  def trace(_event, _env), do: :ok

  defp after_compiler({:error, _} = status, _argv), do: status

  defp after_compiler({status, diagnostics}, _argv) when status in [:ok, :noop] do
    app_name = Keyword.fetch!(Mix.Project.config(), :app)

    # We're reloading the app to make sure we have the latest version. This fixes potential stale state in ElixirLS.
    Application.unload(app_name)
    Application.load(app_name)

    tracers = Enum.reject(Code.get_compiler_option(:tracers), &(&1 == __MODULE__))
    Code.put_compiler_option(:tracers, tracers)

    %{events: events, modules: _modules} = Events.all()

    [full, added, removed] =
      @manifest_events
      |> read_manifest()
      |> case do
        nil ->
          [events, events, %{}]

        old ->
          {related, rest} = Map.split(old, Map.keys(events))
          related_old = MapSet.new(Enum.flat_map(related, &elem(&1, 1)))
          related_new = MapSet.new(Enum.flat_map(events, &elem(&1, 1)))

          [
            Map.merge(rest, events),
            MapSet.difference(related_new, related_old),
            MapSet.difference(related_old, related_new)
          ]
      end

    write_manifest(@manifest_events, full)

    [added, removed]
    |> Enum.map(&Enum.map(&1, fn m -> inspect(m, limit: :infinity) end))
    |> case do
      [[], []] ->
        Mix.shell().info("Telemetry events were not updated")

      [[], rem] ->
        Mix.shell().info(Enum.join(["Telemetry events removed:" | rem], "\n  - "))

      [add, []] ->
        Mix.shell().info(Enum.join(["Telemetry events added:  " | add], "\n  - "))

      [add, rem] ->
        Mix.shell().info(
          "Telemetry events:\n" <>
            Enum.join(["  - added:" | add], "\n    - ") <>
            Enum.join(["  - removed:" | rem], "\n    - ")
        )
    end

    {status, diagnostics ++ [diagnostic("hey there")]}
  end

  defp diagnostic(message, opts \\ []) do
    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "telemetria",
      details: nil,
      file: "unknown",
      message: message,
      position: nil,
      severity: :information
    }
    |> Map.merge(Map.new(opts))
  end

  @spec manifest_path(binary()) :: binary()
  def manifest_path(name),
    do: Mix.Project.config() |> Mix.Project.manifest_path() |> Path.join("compile.#{name}")

  @spec stale_manifest?(binary()) :: boolean()
  def stale_manifest?(name),
    do: Mix.Utils.stale?([Mix.Project.config_mtime()], [manifest_path(name)])

  @spec read_manifest(binary()) :: term()
  def read_manifest(name) do
    unless stale_manifest?(name) do
      name
      |> manifest_path()
      |> File.read()
      |> case do
        {:ok, manifest} -> :erlang.binary_to_term(manifest)
        _ -> nil
      end
    end
  end

  @spec write_manifest(binary(), term()) :: :ok
  def write_manifest(name, data) do
    path = manifest_path(name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(data))
  end
end
