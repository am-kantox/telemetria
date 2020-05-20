defmodule Telemetria.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Telemetria
  alias Test.Telemetria.Example

  test "attaches telemetry events to module functions and spits out logs" do
    log =
      capture_log(fn ->
        Example.sum_with_doubled(1, 3)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :twice]"
    assert log =~ "[:test, :telemetria, :example, :sum_with_doubled]"
  end

  test "attaches telemetry events to anonymous local functions and spits out logs" do
    log =
      capture_log(fn ->
        Example.half(4)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :half]"
  end

  test "attaches telemetry events named and spits out logs" do
    log =
      capture_log(fn ->
        Example.half_named(4)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :half_named, :foo]"
  end

  test "attaches telemetry events to random ast and spits out logs" do
    log =
      capture_log(fn ->
        Example.tmed()
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :tmed]"
  end
end
