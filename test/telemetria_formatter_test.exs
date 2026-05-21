defmodule Telemetria.FormatterTest do
  use ExUnit.Case

  alias Telemetria.Formatter

  @timestamp {{2026, 1, 1}, {12, 0, 0, 0}}

  test "format/4 produces valid JSON with newline" do
    result = Formatter.format(:info, "hello", @timestamp, [])
    json = IO.iodata_to_binary(result)
    assert String.ends_with?(json, "\n")

    decoded = :json.decode(String.trim_trailing(json))
    assert is_map(decoded)
    assert decoded["message"] == "hello"
    assert decoded["severity"] == "info"
    assert decoded["@type"] == "log"
  end

  test "format/4 includes timestamp as ISO8601" do
    json =
      :info
      |> Formatter.format("msg", @timestamp, [])
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["@timestamp"] == "2026-01-01T12:00:00.000Z"
  end

  test "format/4 includes telemetria metadata when present" do
    metadata = [telemetría: [otp_app: :my_app, type: :event]]

    json =
      :warning
      |> Formatter.format("test", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["@id"] == "my_app"
    assert json["@type"] == "event"
    assert json["severity"] == "warning"
  end

  test "format/4 handles structured data in metadata" do
    metadata = [custom_key: %{nested: "value"}]

    json =
      :debug
      |> Formatter.format("structured", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["custom_key"]["nested"] == "value"
  end
end
