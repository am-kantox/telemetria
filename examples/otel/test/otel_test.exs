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

    log =
      capture_log(fn ->
        assert Otel.f_to_c(451) == 233
        Process.sleep(100)
      end)

    # assert log =~ "[warning] Unexpected throttle setting for group `:weather_reports` → nil"

    # nested span
    assert_receive {:span,
                    {:span, _, _, {:tracestate, []}, parent_span_id, "otel.do_f_to_c", :internal, _, _,
                     {:attributes, 128, :infinity, 0,
                      %{
                        "args_fahrenheit" => 451,
                        "context_conditional" => nil,
                        "context_options_group" => :weather_reports,
                        "context_options_level" => :info,
                        "env_file" => _,
                        "env_line" => 13,
                        "env_module" => Otel,
                        "result" => 232.77777777777777,
                        "measurements_consumed" => _,
                        "measurements_system_time_monotonic" => _,
                        "measurements_system_time_system" => _,
                        "telemetria_group" => :weather_reports
                      }},
                     {:events, 128, 128, :infinity, 0,
                      [
                        {:event, _, "otel.do_f_to_c@" <> _, {:attributes, 128, :infinity, 0, %{}}}
                      ]},
                     {:links, 128, 128, :infinity, 0,
                      [
                        {:link, _, _, {:attributes, 128, :infinity, 0, %{}}, {:tracestate, []}}
                      ]}, :undefined, 1, false,
                     {:instrumentation_scope, "telemetria", _, :undefined}}}
                   when is_integer(parent_span_id),
                   1000

    # parent span
    assert_receive {:span,
                    {:span, _, span_id, {:tracestate, []}, :undefined, "otel.f_to_c", :internal, _, _,
                     {:attributes, 128, :infinity, 0,
                      %{
                        "args_fahrenheit" => 451,
                        "context_conditional" => nil,
                        "context_options_group" => :weather_reports,
                        "context_options_level" => :info,
                        "context_options_locals_0" => :celsius,
                        "env_file" => _,
                        "env_line" => 7,
                        "env_module" => Otel,
                        "locals_celsius" => 232.77777777777777,
                        "measurements_consumed" => _,
                        "measurements_system_time_monotonic" => _,
                        "measurements_system_time_system" => _,
                        "result" => 233,
                        "telemetria_group" => :weather_reports
                      }},
                     {:events, 128, 128, :infinity, 0,
                      [
                        {:event, _, "otel.f_to_c@" <> _, {:attributes, 128, :infinity, 0, %{}}}
                      ]}, {:links, 128, 128, :infinity, 1, []}, :undefined, 1, false,
                     {:instrumentation_scope, "telemetria", _, :undefined}}},
                   1000

      assert parent_span_id == span_id
  end
end
