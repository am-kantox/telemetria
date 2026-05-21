defmodule Telemetria.OptionsTest do
  use ExUnit.Case

  alias Telemetria.Options

  describe "schema/0" do
    test "returns a keyword list" do
      assert Keyword.keyword?(Options.schema())
    end

    test "contains all expected top-level keys" do
      keys = Keyword.keys(Options.schema())

      for expected <- ~w|otp_app enabled backend level purge_level throttle
                         strict events handler polling process_info|a do
        assert expected in keys, "expected #{inspect(expected)} in schema keys"
      end
    end
  end

  describe "log_level/1" do
    test "accepts valid log levels" do
      for level <- ~w|emergency alert critical error warning notice info debug|a do
        assert {:ok, ^level} = Options.log_level(level)
      end
    end

    test "rejects invalid log levels" do
      assert {:error, msg} = Options.log_level(:verbose)
      assert msg =~ "verbose"
    end
  end

  describe "mf/1" do
    test "accepts valid MF pair with arity 4" do
      assert {:ok, {Telemetria.Handler.Default, :handle_event}} =
               Options.mf({Telemetria.Handler.Default, :handle_event})
    end

    test "rejects MF pair with wrong arity" do
      assert {:error, msg} = Options.mf({Enum, :map})
      assert msg =~ "arity 4"
    end

    test "rejects MF pair with non-existent module" do
      assert {:error, _} = Options.mf({NonExistent.Module, :fun})
    end
  end

  describe "list/2" do
    test "validates all elements match at least one checker" do
      assert {:ok, [1, 2, 3]} = Options.list([1, 2, 3], [{Kernel, :is_integer}])
    end

    test "rejects when elements do not match" do
      assert {:error, msg} = Options.list([:a, :b], [{Kernel, :is_integer}])
      assert msg =~ "Expected list"
    end
  end

  describe "initial/0" do
    test "returns validated config as keyword list" do
      result = Options.initial()
      assert Keyword.keyword?(result)
      assert Keyword.has_key?(result, :enabled)
      assert Keyword.has_key?(result, :backend)
    end
  end
end
