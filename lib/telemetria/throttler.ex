defmodule Telemetria.Throttler do
  @moduledoc false

  use GenServer

  def start_link(%{} = opts) do
    GenServer.start_link(__MODULE__, %{options: opts, events: %{}}, name: name())
  end

  def execute(group \\ nil, event), do: GenServer.cast(name(), {:event, group || :default, event})

  def name do
    [Telemetria.otp_app(), :telemetria, :throttler]
    |> Enum.map(&Atom.to_string/1)
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end

  @impl GenServer
  def init(state) do
    Enum.each(state.options, fn {group, {interval, kind}} ->
      if kind in [:all, :last] and interval > 0,
        do: Process.send_after(self(), {:work, group}, interval)
    end)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:event, group, event}, state) do
    case Map.get(state.options, group) do
      {_, :all} ->
        {:noreply, %{state | events: Map.update(state.events, group, [event], &[event | &1])}}

      {_, :last} ->
        {:noreply, %{state | events: Map.put(state.events, group, [event])}}

      {_, :none} ->
        do_execute(group, [event])
        {:noreply, state}

      some ->
        require Logger
        Logger.warning("Unexpected throttle setting for group `:#{group}` → " <> inspect(some))
        do_execute(group, [event])
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:work, group}, %{events: events} = state) do
    group_events =
      case Enum.find(events, &match?({^group, _}, &1)) do
        {^group, events} -> events
        _ -> nil
      end

    do_execute(group, group_events)

    send_after = elem(Map.get(state.options, group, 0), 0)
    Process.send_after(self(), {:work, group}, send_after)
    {:noreply, %{state | events: Map.put(events, group, [])}}
  end

  defp do_execute(group, nil) do
    require Logger
    Logger.warning("Wrong config for group: #{group}, skipping")
  end

  defp do_execute(group, {event, measurements, metadata, reshaper, messenger}) do
    {context, updates} =
      metadata
      |> Map.put(:telemetria_group, group)
      |> Map.put(:measurements, measurements)
      |> Map.pop(:context, %{})

    case messenger do
      false ->
        :ok

      nil ->
        :ok

      impl when is_atom(impl) ->
        updates
        |> Map.put(:event, event)
        |> Telemetria.Messenger.post(impl)

      {impl, opts} when is_atom(impl) ->
        updates
        |> Map.put(:event, event)
        |> Telemetria.Messenger.post(impl, opts)
    end

    updates = if is_function(reshaper, 1), do: reshaper.(updates), else: updates

    updates =
      updates
      |> Map.put(:context, context)
      |> Telemetria.Backend.reshape()

    Telemetria.Backend.return(event, updates)
  end

  defp do_execute(group, [event]),
    do: do_execute(group, event)

  defp do_execute(group, events),
    do: events |> Enum.reverse() |> Enum.each(&do_execute(group, &1))
end
