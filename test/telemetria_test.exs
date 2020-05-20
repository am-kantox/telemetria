defmodule TelemetriaTest do
  use ExUnit.Case
  doctest Telemetria
  alias Test.Telemetria.Example

  test "attaches telemetry events and spits out logs" do
    log =
      capture_log(fn ->
        Example.sum_with_doubled(1, 3)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :twice]"
    assert log =~ "[:test, :telemetria, :example, :sum_with_doubled]"
  end
end
