defmodule Telemetria.Handler do
  @moduledoc """
  The behaviour to be implemented by consumers.

  `Telemetría` provides the default handler, that simply delegates to `Logger.info/1`.

  _See:_ `Telemetria.Handler.Default`.
  """

  @doc "The callback that will be invoked by `:telemetry`"
  @callback handle_event(
              :telemetry.event_name(),
              :telemetry.event_measurements(),
              :telemetry.event_metadata(),
              :telemetry.handler_config()
            ) :: :ok

  @type process_info :: [
          {:status, atom()}
          | {:message_queue_len, any()}
          | {:priority, any()}
          | {:total_heap_size, any()}
          | {:heap_size, any()}
          | {:stack_size, any()}
          | {:reductions, any()}
          | {:garbage_collection,
             [
               {:fullsweep_after, non_neg_integer()}
               | {:max_heap_size,
                  %{error_logger: boolean(), kill: boolean(), size: non_neg_integer()}}
               | {:min_bin_vheap_size, non_neg_integer()}
               | {:min_heap_size, non_neg_integer()}
               | {:minor_gcs, non_neg_integer()}
             ]}
          | {:schedulers, non_neg_integer()}
        ]
  @spec process_info(pid :: nil | pid()) :: process_info()
  @doc "Collects and formats the current process info to insert to metadata"
  def process_info(pid \\ nil) do
    (pid || self())
    |> Process.info()
    |> Kernel.||([])
    |> Keyword.take([
      :status,
      :message_queue_len,
      :priority,
      :total_heap_size,
      :heap_size,
      :stack_size,
      :reductions,
      :garbage_collection
    ])
    |> Keyword.put(:schedulers, System.schedulers())
  end
end
