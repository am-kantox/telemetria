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

  test "format/4 handles pid values" do
    metadata = [my_pid: self()]

    json =
      :info
      |> Formatter.format("pid test", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert is_binary(json["my_pid"])
    assert json["my_pid"] =~ "<"
  end

  test "format/4 handles Date and Time values" do
    metadata = [
      today: ~D[2026-06-15],
      now: ~T[14:30:00]
    ]

    json =
      :info
      |> Formatter.format("datetime", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["today"] == "2026-06-15"
    assert json["now"] == "14:30:00"
  end

  test "format/4 handles atom values" do
    metadata = [status: :active]

    json =
      :info
      |> Formatter.format("atom", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["status"] == "active"
  end

  test "format/4 handles tuple values" do
    metadata = [pair: {:ok, 42}]

    json =
      :info
      |> Formatter.format("tuple", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert is_list(json["pair"])
    assert [_, _] = json["pair"]
  end

  test "format/4 handles lists of values" do
    metadata = [items: [1, 2, 3]]

    json =
      :info
      |> Formatter.format("list", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["items"] == [1, 2, 3]
  end

  test "format/4 handles struct values" do
    metadata = [range: 1..10]

    json =
      :info
      |> Formatter.format("struct", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert is_map(json["range"])
  end

  test "format/4 handles numeric values" do
    metadata = [count: 42, ratio: 3.14]

    json =
      :info
      |> Formatter.format("numbers", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["count"] == 42
    assert json["ratio"] == 3.14
  end

  test "format/4 handles reference values" do
    ref = make_ref()
    metadata = [ref: ref]

    json =
      :info
      |> Formatter.format("ref", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert is_binary(json["ref"])
    assert json["ref"] =~ "#Ref"
  end

  test "format/4 handles DateTime values in metadata" do
    metadata = [recorded_at: ~U[2026-03-15 10:30:00Z]]

    json =
      :info
      |> Formatter.format("dt", @timestamp, metadata)
      |> IO.iodata_to_binary()
      |> String.trim_trailing()
      |> :json.decode()

    assert json["recorded_at"] == "2026-03-15T10:30:00Z"
  end

  test "format/4 severity defaults to the level argument" do
    for level <- [:debug, :info, :warning, :error] do
      json =
        level
        |> Formatter.format("level test", @timestamp, [])
        |> IO.iodata_to_binary()
        |> String.trim_trailing()
        |> :json.decode()

      assert json["severity"] == Atom.to_string(level)
    end
  end
end
