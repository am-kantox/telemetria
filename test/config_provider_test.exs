defmodule Telemetria.ConfigProviderTest do
  use ExUnit.Case

  alias Telemetria.ConfigProvider

  describe "json_config!/1" do
    test "returns empty list when file does not exist" do
      assert [] == ConfigProvider.json_config!("/tmp/nonexistent_telemetria_config.json")
    end

    test "parses a valid JSON config file" do
      path = Path.join(System.tmp_dir!(), "telemetria_test_config.json")

      json =
        :json.encode(%{
          "otp_app" => "my_app",
          "events" => [["my_app", "user", "create"]]
        })
        |> IO.iodata_to_binary()

      File.write!(path, json)

      result = ConfigProvider.json_config!(path)
      assert Keyword.keyword?(result)
      assert Keyword.has_key?(result, :otp_app)
    after
      path = Path.join(System.tmp_dir!(), "telemetria_test_config.json")
      File.rm(path)
    end
  end

  describe "load/2" do
    test "merges JSON config into existing config" do
      path = Path.join(System.tmp_dir!(), "telemetria_test_load.json")

      json =
        :json.encode(%{
          "otp_app" => "loaded_app",
          "events" => [["loaded", "event"]]
        })
        |> IO.iodata_to_binary()

      File.write!(path, json)

      config = [telemetria: [enabled: true]]
      result = ConfigProvider.load(config, path)

      telemetria_config = Keyword.get(result, :telemetria, [])
      assert Keyword.has_key?(telemetria_config, :otp_app)
    after
      path = Path.join(System.tmp_dir!(), "telemetria_test_load.json")
      File.rm(path)
    end
  end

  describe "init/1" do
    test "returns the path as-is" do
      assert "/some/path.json" == ConfigProvider.init("/some/path.json")
    end
  end
end
