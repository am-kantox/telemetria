defmodule Telemetria.Mix.Events do
  @moduledoc false

  @json_config_path Application.get_env(
                      :telemetry,
                      :json_config_path,
                      Path.join(["config", ".telemetria.config.json"])
                    )

  use Boundary, deps: [], exports: []

  use Agent

  def start_link,
    do: Agent.start_link(fn -> %{events: %{}, diagnostics: MapSet.new()} end, name: __MODULE__)

  def all, do: Agent.get(__MODULE__, & &1)

  def put(:event, {module, event}) do
    Agent.update(
      __MODULE__,
      &update_in(&1, [:events, module], fn
        nil -> MapSet.new([event])
        events -> MapSet.put(events, event)
      end)
    )
  end

  def put(:diagnostic, diagnostic),
    do:
      Agent.update(
        __MODULE__,
        &Map.update!(&1, :diagnostics, fn diagnostics -> MapSet.put(diagnostics, diagnostic) end)
      )

  @doc false
  @spec json_config_path :: binary()
  {:compile, inline: [json_config_path: 0]}
  def json_config_path, do: @json_config_path
end
