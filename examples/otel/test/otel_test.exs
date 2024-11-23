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

    assert log =~ "[warning] Unexpected throttle setting for group `:weather_reports` → nil"

    assert_receive {:span,
                    {:span, _, _, {:tracestate, []}, :undefined, "otel.f_to_c", :internal, _, _,
                     {:attributes, 128, :infinity, 0,
                      %{
                        "args_fahrenheit" => 451,
                        "context_conditional" => nil,
                        "context_options_group" => :weather_reports,
                        "context_options_level" => :info,
                        "context_options_locals_0" => :celsius,
                        "env_file" =>
                          "/home/am/Proyectos/Elixir/telemetria/examples/otel/lib/otel.ex",
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
                      ]}, {:links, 128, 128, :infinity, 0, []}, :undefined, 1, false,
                     {:instrumentation_scope, "telemetria", _, :undefined}}},
                   1000
  end
end
