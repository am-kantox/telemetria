defmodule Telemetria.Mix.Events do
  @moduledoc false

  use Agent

  def start_link(),
    do: Agent.start_link(fn -> %{events: %{}, modules: MapSet.new()} end, name: __MODULE__)

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

  def put(:module, module),
    do:
      Agent.update(
        __MODULE__,
        &Map.update!(&1, :modules, fn modules -> MapSet.put(modules, module) end)
      )
end
