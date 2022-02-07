defmodule Mix.Tasks.Compile.Telemetria do
  # credo:disable-for-this-file Credo.Check.Readability.Specs
  @moduledoc false

  use Boundary, deps: [Telemetria]

  use Mix.Task.Compiler

  alias Mix.Task.Compiler
  alias Telemetria.{Hooks, Mix.Events}

  @preferred_cli_env :dev
  @manifest_events "telemetria_events"

  @impl Compiler
  def run(argv) do
    :ok = Application.ensure_started(:telemetry)
    Events.start_link()

    Compiler.after_compiler(:app, &after_compiler(&1, argv))

    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [__MODULE__ | tracers])

    {:ok, []}
  end

  @doc false
  @impl Compiler
  def manifests, do: [manifest_path(@manifest_events)]

  @doc false
  @impl Compiler
  def clean do
    with {:ok, files} <- File.rm_rf(Events.json_config_path()),
         do: Mix.shell().info("Telemetria JSON config cleaned up: #{inspect(files)}")

    :ok
  end

  @doc false
  def trace({remote, meta, Telemetria, :__using__, 1}, env)
      when remote in ~w/remote_macro imported_macro/a do
    pos = if Keyword.keyword?(meta), do: Keyword.get(meta, :line, env.line)
    message = "This file contains Telemetria calls, see diagnostics below"

    Events.put(
      :diagnostic,
      diagnostic(message, details: env.context, position: pos, file: env.file)
    )

    :ok
  end

  def trace({:remote_macro, _meta, Telemetria.Hooks, :__before_compile__, 1}, env) do
    env.module
    |> Module.get_attribute(:telemetria_hooks, [])
    |> Enum.each(fn
      %Hooks{annotation_type: :head} = hook ->
        # [TODO] Point to all the clauses of guarged function
        event = Telemetria.telemetry_prefix(env, {hook.fun, [line: hook.env.line], hook.args})

        message =
          "All clauses of the annotated function are to be wrapped in Telemetria event with id: #{inspect(event)}"

        Events.put(
          :diagnostic,
          diagnostic(message, details: env.context, position: hook.env.line, file: hook.env.file)
        )

      %Hooks{annotation_type: :clause} = hook ->
        event = Telemetria.telemetry_prefix(env, {hook.fun, [line: hook.env.line], hook.args})

        message =
          "Annotated function is to be wrapped in Telemetria event with id: #{inspect(event)}"

        Events.put(
          :diagnostic,
          diagnostic(message, details: env.context, position: hook.env.line, file: hook.env.file)
        )

      %Hooks{} = _hook ->
        :ok
    end)

    :ok
  end

  def trace(_event, _env), do: :ok

  @spec store_config :: :ok | {:error, :manifest_missing}
  def store_config, do: @manifest_events |> read_manifest() |> do_store_config()

  @spec do_store_config(nil | term()) :: :ok | {:error, any()}
  defp do_store_config(nil), do: {:error, :manifest_missing}

  defp do_store_config(manifest) do
    json = Jason.encode!(%{otp_app: app_name(), events: Enum.flat_map(manifest, &elem(&1, 1))})

    File.mkdir_p!(Path.dirname(Events.json_config_path()))
    File.write(Events.json_config_path(), json)
  end

  @spec app_name :: atom()
  defp app_name, do: Keyword.fetch!(Mix.Project.config(), :app)

  @spec after_compiler({status, [Mix.Task.Compiler.Diagnostic.t()]}, any()) ::
          {status, [Mix.Task.Compiler.Diagnostic.t()]}
        when status: atom()
  defp after_compiler({status, diagnostics}, _argv) do
    # If succeeded, we're reloading the app to make sure we have the latest version.
    # This fixes potential stale state in ElixirLS.
    if status in [:ok, :noop] do
      app_name = app_name()
      Application.unload(app_name)
      Application.load(app_name)
    end

    tracers = Enum.reject(Code.get_compiler_option(:tracers), &(&1 == __MODULE__))
    Code.put_compiler_option(:tracers, tracers)

    %{events: events, diagnostics: telemetria_diagnostics} = Events.all()

    [full, added, removed] =
      @manifest_events
      |> read_manifest()
      |> case do
        nil ->
          [events, MapSet.new(Enum.flat_map(events, fn {_, e} -> e end)), MapSet.new()]

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
        ["Telemetry events removed:" | rem]
        |> Enum.join("\n  - ")
        |> Mix.shell().info()

      [add, []] ->
        ["Telemetry events added:  " | add]
        |> Enum.join("\n  - ")
        |> Mix.shell().info()

      [add, rem] ->
        Mix.shell().info(
          "Telemetry events:" <>
            Enum.join(["\n  - added:" | add], "\n    - ") <>
            Enum.join(["\n  - removed:" | rem], "\n    - ")
        )
    end

    {status, diagnostics ++ MapSet.to_list(telemetria_diagnostics)}
  end

  @spec diagnostic(message :: binary(), opts :: keyword()) :: Mix.Task.Compiler.Diagnostic.t()
  defp diagnostic(message, opts) do
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
  defp manifest_path(name),
    do: Mix.Project.config() |> Mix.Project.manifest_path() |> Path.join("compile.#{name}")

  @spec read_manifest(binary()) :: term()
  defp read_manifest(name) do
    unless Mix.Utils.stale?([Mix.Project.config_mtime()], [manifest_path(name)]) do
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
  defp write_manifest(name, data) do
    path = manifest_path(name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(data))

    do_store_config(data)
  end
end
