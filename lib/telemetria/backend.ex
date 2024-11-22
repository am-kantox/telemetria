defmodule Telemetria.Backend do
  @moduledoc """
  This behaviour should be implemented by the backend, used for actual
  telemetry events processing.
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

  @implementation Telemetria.Application.backend()

  case @implementation do
    module when is_atom(module) ->
      defdelegate entry(block_id), to: @implementation
      defdelegate return(block_context, context), to: @implementation
      defdelegate update(block_context, updates), to: @implementation

    list when is_list(list) ->
      def entry(block_id) do
        Enum.each(@implementation, & &1.entry(block_id))
      end

      def return(block_context, context) do
        Enum.each(@implementation, & &1.return(block_context, context))
      end

      def update(block_context, updates) do
        Enum.each(@implementation, & &1.update(block_context, updates))
      end
  end
end
