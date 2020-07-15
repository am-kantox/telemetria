defmodule Telemetria.FormatterTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Test.Telemetria.Example

  setup_all do
    Application.put_env(
      :logger,
      :console,
      [
        metadata: :all,
        format: {Telemetria.Formatter, :format}
      ],
      persistent: true
    )

    Application.put_env(:telemetria, :smart_log, true)
  end

  test "attaches telemetry events to module functions and spits out logs" do
    log =
      capture_log(fn ->
        Example.sum_with_doubled(1, 3)
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"twice\"]|
    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"sum_with_doubled\"]|
    assert log =~ ~s|\"result\":7|
  end

  test "attaches telemetry events to anonymous local functions and spits out logs" do
    log =
      capture_log(fn ->
        Example.half(42)
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"half\"]|
    assert log =~ ~s|\"args\":{\"a\":42}|
    assert log =~ ~s|\"result\":21|
  end

  test "attaches telemetry events named and spits out logs" do
    log =
      capture_log(fn ->
        Example.half_named(4)
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"half_named\",\"foo\"]|
    assert log =~ ~s|\"result\":\"#Function<|
  end

  test "attaches telemetry events to random ast and spits out logs" do
    log =
      capture_log(fn ->
        Example.tmed()
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"tmed\"]|
    assert log =~ ~s|\"result\":42|
  end

  test "attaches telemetry events to random ast with do-end syntax and spits out logs" do
    log =
      capture_log(fn ->
        Example.tmed_do()
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"tmed_do\"]|
    assert log =~ ~s|\"result\":42|
  end

  test "attaches telemetry events to guarded function and spits out logs" do
    log =
      capture_log(fn ->
        assert 84 == Example.guarded(42)
        assert :ok == Example.guarded(:ok)
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"guarded\"]|
    assert log =~ ~s|\"result\":84|
    assert log =~ ~s|\"result\":\"ok\"|
  end

  test "@telemetry true" do
    log =
      capture_log(fn ->
        assert 42 == Example.annotated_1(42)
        Process.sleep(100)
      end)

    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"annotated_1\"]|
    assert log =~ ~s|[\"test\",\"telemetria\",\"example\",\"annotated_2\"]|
    assert log =~ ~s|\"result\":42|
  end

  test "@telemetry level:" do
    log =
      capture_log(fn ->
        assert 42 == Example.annotated_1(42)
        Process.sleep(100)
      end)

    assert log =~ ~s|event\":[\"test\",\"telemetria\",\"example\",\"annotated_1\"]|
    assert log =~ ~s|event\":[\"test\",\"telemetria\",\"example\",\"annotated_2\"]|
    assert log =~ ~s|\"result\":42|
  end
end
