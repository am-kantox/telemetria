case {Telemetria.Application.telemetry?(), Code.ensure_compiled(:telemetry)} do
  {true, {:module, :telemetry}} ->
    defmodule Telemetria.Backend.Telemetry do
      @moduledoc """
      The implementation of `Telemetria.Backend` for `:telemetry`.
      """

      @behaviour Telemetria.Backend

      @impl true
      def entry(block_id), do: block_id

      @impl true
      def update(block_id, _updates), do: block_id

      @impl true
      def return(block_id, context) do
        {measurements, metadata} = Map.pop(context, :measurements, %{})
        :telemetry.execute(block_id, measurements, metadata)
      end

      @impl true
      def reshape(updates), do: updates
    end

  _ ->
    defmodule Telemetria.Backend.Telemetry do
      @moduledoc """
      The implementation of `Telemetria.Backend` for `:telemetry`.
      """
    end
end
