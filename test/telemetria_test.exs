defmodule Telemetria.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Telemetria

  test "attaches telemetry events and spits out logs" do
    log =
      capture_log(fn ->
        Test.Telemetria.Example.sum_with_doubled(1, 3)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :twice]"
    assert log =~ "[:test, :telemetria, :example, :sum_with_doubled]"
  end
end
