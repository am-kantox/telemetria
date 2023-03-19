defmodule Telemetria.Polling do
  @moduledoc false

  use Supervisor
  require Logger
  alias Telemetria.{Instrumenter, Polling}

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts),
    do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Supervisor
  def init(opts),
    do: do_init(Keyword.get(opts, :enabled, true), Instrumenter.buffer(), opts)

  @spec do_init(boolean(), pid(), keyword()) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore

  defp do_init(true, buffer, opts) when is_pid(buffer) do
    children = [
      :telemetry_poller.child_spec(
        measurements: [
          {Polling, :system_info, []},
          {Polling, :process_info, []}
        ],
        period: Keyword.fetch!(opts, :poll),
        name: :poller
      ),
      :telemetry_poller.child_spec(
        measurements: [{Polling, :flush, [buffer]}],
        period: Keyword.fetch!(opts, :flush),
        name: :flusher
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp do_init(false, _pid, _opts) do
    Logger.info("Polling disabled by options")
    :ignore
  end

  defp do_init(_, pid, opts) do
    Logger.error(
      "Cannot start polling, bad buffer (" <>
        inspect(pid) <> ") or options: (" <> inspect(opts) <> ")"
    )

    :ignore
  end

  @doc false
  @spec system_info :: %{
          process_count: any(),
          process_limit: any(),
          atom_count: any(),
          atom_limit: any(),
          port_count: any(),
          port_limit: any()
        }
  def system_info do
    info = %{
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit),
      port_count: :erlang.system_info(:port_count),
      port_limit: :erlang.system_info(:port_limit)
    }

    :telemetry.execute([Instrumenter.otp_app(), :vm, :system_info], info)
    info
  end

  @doc false
  @spec process_info :: %{
          heap_size: non_neg_integer(),
          message_queue_len: non_neg_integer(),
          stack_size: non_neg_integer(),
          total_heap_size: non_neg_integer()
        }
  def process_info do
    info =
      Enum.reduce(:erlang.processes(), %{}, fn pid, acc ->
        info =
          case :erlang.process_info(pid) do
            :undefined -> []
            info -> info
          end

        heap_size = Keyword.get(info, :heap_size, 0)
        message_queue_len = Keyword.get(info, :message_queue_len, 0)
        stack_size = Keyword.get(info, :stack_size, 0)
        total_heap_size = Keyword.get(info, :total_heap_size, 0)

        acc
        |> Map.update(:heap_size, 0, &(&1 + heap_size))
        |> Map.update(:message_queue_len, 0, &(&1 + message_queue_len))
        |> Map.update(:stack_size, 0, &(&1 + stack_size))
        |> Map.update(:total_heap_size, 0, &(&1 + total_heap_size))
      end)

    :telemetry.execute([Instrumenter.otp_app(), :vm, :process_info], info)
    info
  end

  @spec flush(pid()) :: :ok
  def flush(buffer) do
    buffer
    |> StringIO.flush()
    |> IO.write()
  end
end
