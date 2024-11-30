defmodule TmTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  doctest Tm

  setup_all do
    Application.put_env(:logger, :console, [], persistent: true)
  end

  test "converts fahrenheit to celsius (capture)" do
    log =
      capture_log(fn ->
        assert Tm.f_to_c(451) == 233
        Process.sleep(500)
      end)

    assert log =~ "[warning] Unexpected throttle setting for group `:weather_reports` → nil"

    assert log =~
             "[info] [telemetría: [otp_app: :telemetria, severity: :info, type: :metrics, event: [:tm, :f_to_c]"
  end

  test "converts fahrenheit to celsius (with)" do
    {:ok, log} =
      with_log(fn ->
        Tm.f_to_c(451)
        Process.sleep(500)
      end)

    assert log =~
             "call: [args: [fahrenheit: 451], result: 233, locals: [celsius: 232.77777777777777]]"
  end
end
