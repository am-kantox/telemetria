defmodule Telemetria.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Telemetria
  alias Test.Telemetria.Example

  setup_all do
    Application.put_env(:logger, :console, [], persistent: true)
    Application.put_env(:telemetria, :smart_log, false)
  end

  test "attaches telemetry events to module functions and spits out logs" do
    log =
      capture_log(fn ->
        Example.sum_with_doubled(1, 3)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :twice]"
    assert log =~ "[:test, :telemetria, :example, :sum_with_doubled]"
    assert log =~ "result: 7"
  end

  test "attaches telemetry events to anonymous local functions and spits out logs" do
    log =
      capture_log(fn ->
        Example.half(42)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :half]"
    assert log =~ "args: [a: 42]"
    assert log =~ "result: 21"
  end

  test "attaches telemetry events named and spits out logs" do
    log =
      capture_log(fn ->
        Example.half_named(4)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :half_named, :foo]"
    assert log =~ "result: #Function<"
  end

  test "attaches telemetry events to random ast and spits out logs" do
    log =
      capture_log(fn ->
        Example.tmed()
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :tmed]"
    assert log =~ "result: 42"
  end

  test "attaches telemetry events to random ast with do-end syntax and spits out logs" do
    log =
      capture_log(fn ->
        Example.tmed_do()
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :tmed_do]"
    assert log =~ "result: 42"
  end

  test "attaches telemetry events to guarded function and spits out logs" do
    log =
      capture_log(fn ->
        assert 84 == Example.guarded(42)
        assert :ok == Example.guarded(:ok)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :guarded]"
    assert log =~ "result: 84"
    assert log =~ "result: :ok"
  end

  test "@telemetry true" do
    log =
      capture_log(fn ->
        assert 42 == Example.annotated_1(42)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :annotated_1]"
    assert log =~ "[:test, :telemetria, :example, :annotated_2]"
    assert log =~ "result: 42"
  end

  test "@telemetry level:" do
    log =
      capture_log(fn ->
        assert 42 == Example.annotated_1(42)
        Process.sleep(100)
      end)

    assert log =~ "event: [:test, :telemetria, :example, :annotated_1]"
    assert log =~ "event: [:test, :telemetria, :example, :annotated_2]"
    assert log =~ "result: 42"
  end

  test "@telemetry deep pattern match" do
    log =
      capture_log(fn ->
        assert {:ok, :bar} = Example.check_s(%Test.Telemetria.S{foo: :not_42})
        assert {:error, _} = Example.check_s(%Test.Telemetria.S{foo: :not_42, bar: :not_baz})
        assert {:ok, :foo} == Example.check_s(%Test.Telemetria.S{})
        Process.sleep(100)
      end)

    assert log =~ "event: [:test, :telemetria, :example, :check_s]"
  end

  test "@telemetry different clauses" do
    log =
      capture_log(fn ->
        assert 0 == Example.annotated_3(nil)
        assert 42 == Example.annotated_3("42")
        assert 42 == Example.annotated_3(42)
        Process.sleep(100)
      end)

    assert log =~ "[:test, :telemetria, :example, :annotated_3]"
    assert log =~ "result: 42"
  end
end
