defmodule Telemetria.Error do
  defexception [:message]

  @impl true
  def exception(message) when is_binary(message) do
    %Telemetria.Error{message: message}
  end
end
