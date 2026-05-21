defmodule OtelTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  doctest Otel

  # Use Record module to extract fields of the Span record from the opentelemetry dependency.
  require Record
  @fields Record.extract(:span, from: "deps/opentelemetry/include/otel_span.hrl")
  # Define macros for `Span`.
  Record.defrecordp(:span, @fields)

  test "converts fahrenheit to celsius (capture)" do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    _log =
      capture_log(fn ->
        assert Otel.f_to_c(451) == 233
        Process.sleep(100)
      end)

    # assert log =~ "[warning] Unexpected throttle setting for group `:weather_reports` → nil"

    # parent span
    assert_receive {:span,
                    {:span, _, span_id, {:tracestate, []}, _, _, "otel.f_to_c", :internal, _, _,
                     {:attributes, 128, :infinity, 0,
                      %{
                        "args_fahrenheit" => 451,
                        "env_module" => Otel,
                        "env_line" => 7,
                        "locals_celsius" => 232.77777777777777,
                        "result" => 233,
                        "telemetria_group" => :weather_reports
                      }},
                     {:events, 128, 128, :infinity, 0,
                      [
                        {:event, _, "otel.f_to_c@" <> _, _}
                      ]}, _, :undefined, 1, false,
                     {:instrumentation_scope, "telemetria", _, :undefined}}},
                   1000

    # nested span
    assert_receive {:span,
                    {:span, _, _, {:tracestate, []}, parent_span_id, _, "otel.do_f_to_c", :internal,
                     _, _,
                     {:attributes, 128, :infinity, 0,
                      %{
                        "args_fahrenheit" => 451,
                        "env_module" => Otel,
                        "env_line" => 13,
                        "result" => 232.77777777777777,
                        "telemetria_group" => :weather_reports
                      }},
                     {:events, 128, 128, :infinity, 0,
                      [
                        {:event, _, "otel.do_f_to_c@" <> _, _}
                      ]}, _, :undefined, 1, false,
                     {:instrumentation_scope, "telemetria", _, :undefined}}}
                   when is_integer(parent_span_id),
                   1000

      assert parent_span_id == span_id
  end
end
