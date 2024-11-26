defmodule Telemetria.Backend do
  @moduledoc """
  This behaviour should be implemented by the backend, used for actual
  telemetry events processing.

  Backend shipped with the library:

  - `Telemetria.Backend.Telemetry`
  - `Telemetria.Backend.OpenTelemetry`
  """

  @typedoc "The type used for naming blocks / events"
  @type block_id :: Telemetria.event_name()

  @typedoc """
  The context of the currently processing block.

  For instance, `opentelemetry:span_ctx()` for `otel` or `nil` for `telemetry`
  """
  @type block_context :: any()

  @typedoc "The additional attributes of the block, aside from measurements"
  @type block_metadata :: map()

  @doc "The implementation will be called when the block gets entered"
  @callback entry(block_id()) :: block_context()

  @doc "The implementation will be called when the block gets exited / executed"
  @callback return(block_context(), block_context()) :: :ok

  @doc "The implementation will be called when the block context is to be updated"
  @callback update(block_context(), block_metadata()) :: block_context()

  @doc "The implementation will be called to reshape the event before sending it to the actual handler"
  @callback reshape(block_metadata()) :: block_metadata()

  @optional_callbacks reshape: 1

  @implementation Telemetria.Application.backend()

  case @implementation do
    module when is_atom(module) ->
      @doc false
      defdelegate entry(block_id), to: @implementation
      @doc false
      defdelegate return(block_context, context), to: @implementation
      @doc false
      defdelegate update(block_context, updates), to: @implementation
      @doc false
      if function_exported?(@implementation, :reshape, 1) do
        defdelegate reshape(updates), to: @implementation
      else
        def reshape(updates), do: updates
      end

    list when is_list(list) ->
      if Enum.any?(@implementation, &function_exported?(&1, :reshape, 1)) do
        IO.warn("[telemetría] `reshape/1` is ignored when several backends are specified")
      end

      @doc false
      def entry(block_id),
        do: Enum.each(@implementation, & &1.entry(block_id))

      @doc false
      def return(block_context, context),
        do: Enum.each(@implementation, & &1.return(block_context, context))

      @doc false
      def update(block_context, updates),
        do: Enum.each(@implementation, & &1.update(block_context, updates))

      @doc false
      def reshape(updates), do: updates
  end
end
