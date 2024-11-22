case {Telemetria.Application.open_telemetry?(), Code.ensure_compiled(OpenTelemetry)} do
  {true, {:module, OpenTelemetry}} ->
    defmodule Telemetria.Backend.OpenTelemetry do
      @moduledoc """
      The implementation of `Telemetria.Backend` for `OpenTelemetry`.
      """

      require OpenTelemetry.Tracer, as: Tracer

      alias OpenTelemetry.Span

      @behaviour Telemetria.Backend

      @impl true
      def entry(block_id), do: Tracer.start_span(block_id)

      @impl true
      def update(block_id, updates) when is_list(block_id),
        do: block_id |> Enum.join(".") |> update(updates)

      def update(block_id, %{} = updates),
        do: update(block_id, Map.to_list(updates))

      def update(block_id, updates) when is_list(updates) do
        event = OpenTelemetry.event(block_id, updates)
        Tracer.add_events([event])
      end

      @impl true
      def return(block_id, context) do
        Span.set_attributes(block_id, context)
        Span.end_span(block_id)
      end
    end

  _ ->
    nil
end
