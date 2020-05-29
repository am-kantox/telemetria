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
        Example.half(42)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :half]"
    assert log =~ "arguments: [a: 42]"
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

  test "attaches telemetry events to random ast with do-end syntax and spits out logs" do
    log =
      capture_log(fn ->
        Example.tmed_do()
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :tmed_do]"
  end

  test "attaches telemetry events to guarded function and spits out logs" do
    log =
      capture_log(fn ->
        assert 84 == Example.guarded(42)
        assert :ok == Example.guarded(:ok)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :guarded]"
  end

  test "@telemetry true" do
    log =
      capture_log(fn ->
        assert 42 == Example.annotated_1(42)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :annotated_1]"
    assert log =~ "[:test, :telemetria, :example, :annotated_2]"
  end
end
