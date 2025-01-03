defmodule Otel do
  @moduledoc "`Telemetria` with :opentelemetry` example"

  use Telemetria

  @telemetria level: :info, group: :weather_reports, locals: [:celsius], messenger: :slack
  def f_to_c(fahrenheit) do
    celsius = do_f_to_c(fahrenheit)
    round(celsius)
  end

  @telemetria level: :info, group: :weather_reports
  defp do_f_to_c(fahrenheit), do: (fahrenheit - 32) * 5 / 9
end
