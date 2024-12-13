defmodule Telemetria.Backend.Logger do
  @moduledoc """
  The implementation of `Telemetria.Backend` for `Logger`.
  """

  @behaviour Telemetria.Backend

  require Logger

  @impl true
  def entry(block_id), do: block_id

  @impl true
  def update(block_id, _updates), do: block_id

  @impl true
  def return(block_id, context) do
    {measurements, metadata} = Map.pop(context, :measurements, %{})
    Logger.info(inspect(event: block_id, measurements: measurements, metadata: metadata))
  end

  @impl true
  def exit(_block_id), do: :ok

  @impl true
  def reshape(updates), do: updates
end
