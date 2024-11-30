defmodule Telemetria.Messenger.Logger do
  @moduledoc false

  require Logger

  @behaviour Telemetria.Messenger

  @impl true
  def format(message, opts), do: inspect(message, opts)

  Enum.each(~w|debug info warning error|a, fn level ->
    @impl true
    def unquote(level)(message, opts),
      do: post(unquote(level), message, opts)
  end)

  defp post(level, message, opts), do: {Logger.log(level, message), opts}
end
