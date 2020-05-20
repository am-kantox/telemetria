Application.ensure_started(:telemetry)

defmodule Test.Telemetria.Example do
  use Boundary, deps: [Telemetria], exports: []

  import Telemetria

  defpt twice(a) do
    a * 2
  end

  deft sum_with_doubled(a1, a2) do
    a1 + twice(a2)
  end

  def half(a) do
    divider =
      t(fn
        a when is_integer(a) -> a / 2
        _ -> nil
      end)

    divider.(a)
  end

  def half_named(a) do
    t(&(&1 / 2), :foo).(a)
  end

  def tmed, do: t(21 + 21)
end
