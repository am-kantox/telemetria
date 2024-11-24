defmodule Tm do
  @moduledoc "`Telemetria` with :telemetry` example"

  use Telemetria

  @telemetria level: :info, group: :weather_reports, locals: [:celsius]
  def f_to_c(fahrenheit) do
    celsius = (fahrenheit - 32) * 5 / 9
    round(celsius)
  end
end
