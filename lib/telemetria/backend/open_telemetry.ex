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
      def entry(block_id) do
        OpenTelemetry.Ctx.get_current()
        |> OpenTelemetry.Ctx.attach()

        block_id
        |> fix_block_id()
        |> Tracer.start_span()
        |> tap(&Tracer.set_current_span/1)
      end

      @impl true
      def update(block_id, %{} = updates),
        do: update(block_id, Map.to_list(updates))

      def update(block_id, updates) when is_list(updates) do
        event_id = Enum.join([fix_block_id(block_id), "@", System.monotonic_time()])
        updates = Estructura.Flattenable.flatten(updates, jsonify: true)

        Tracer.add_events([OpenTelemetry.event(event_id, updates)])
      end

      @impl true
      def return(block_ctx, context) do
        attributes = Estructura.Flattenable.flatten(context, jsonify: true)

        Span.set_attributes(block_ctx, attributes)
        Span.end_span(block_ctx)
        OpenTelemetry.Ctx.detach(block_ctx)

        :ok
      end

      defp fix_block_id(block_id) when is_list(block_id), do: Enum.join(block_id, ".")
      defp fix_block_id(block_id), do: block_id
    end

  _ ->
    nil
end
