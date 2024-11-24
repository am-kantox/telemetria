defmodule Otel.Test.WithSpan do
  @moduledoc false

  require OpenTelemetry.Tracer, as: Tracer

  alias OpenTelemetry.Span

  def with_span do
    Tracer.with_span :span_1, %{attributes: [{:"start-opts-attr", <<"start-opts-value">>}]} do
      Tracer.set_attributes([
        {:"my-attributes", "my-value"},
        {:another_attribute, "value-of-attributes"}
      ])
    end
  end

  def start_end_span do
    ctx = OpenTelemetry.Ctx.get_current()
    OpenTelemetry.Ctx.attach(ctx)

    span_ctx = Tracer.start_span(:span_2)

    Tracer.set_current_span(span_ctx)

    event = OpenTelemetry.event(:event_1, %{event: :foo})
    Tracer.add_events([event])

    Span.set_attributes(span_ctx, %{attrs: :bar})
    Span.end_span(span_ctx)
    OpenTelemetry.Ctx.detach(span_ctx)
  end
end
