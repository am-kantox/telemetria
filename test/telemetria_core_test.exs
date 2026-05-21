defmodule Telemetria.CoreTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "Telemetria.otp_app/0" do
    test "returns configured otp_app or a fallback" do
      result = Telemetria.otp_app()
      assert is_atom(result)
    end
  end

  describe "Telemetria.noop/1" do
    test "returns the argument unchanged" do
      assert 42 == Telemetria.noop(42)
      assert :hello == Telemetria.noop(:hello)
      assert %{a: 1} == Telemetria.noop(%{a: 1})
    end
  end

  describe "Telemetria.yes/1" do
    test "always returns true" do
      assert true == Telemetria.yes(nil)
      assert true == Telemetria.yes(42)
      assert true == Telemetria.yes(:anything)
    end
  end

  describe "Telemetria.telemetry_prefix/2" do
    test "builds prefix from module and function call" do
      env = %Macro.Env{module: MyApp.Worker, function: {:process, 1}}
      call = {:do_work, [], []}

      result = Telemetria.telemetry_prefix(env, call)
      assert [:my_app, :worker, :process, :do_work] == result
    end

    test "handles nil module" do
      env = %Macro.Env{module: nil, function: nil}
      result = Telemetria.telemetry_prefix(env, [])
      assert [:module_scope] == result
    end

    test "handles suffix list" do
      env = %Macro.Env{module: Foo.Bar, function: nil}
      result = Telemetria.telemetry_prefix(env, [:custom, :suffix])
      assert [:foo, :bar, :custom, :suffix] == result
    end

    test "deduplicates consecutive identical atoms" do
      env = %Macro.Env{module: Foo, function: {:foo, 0}}
      result = Telemetria.telemetry_prefix(env, {:foo, [], []})
      assert [:foo] == result
    end
  end
end

defmodule Telemetria.ErrorTest do
  use ExUnit.Case

  describe "Telemetria.Error" do
    test "creates exception with message" do
      error = Telemetria.Error.exception("something went wrong")
      assert %Telemetria.Error{message: "something went wrong"} = error
    end

    test "can be raised and rescued" do
      assert_raise Telemetria.Error, "boom", fn ->
        raise Telemetria.Error, "boom"
      end
    end
  end
end

defmodule Telemetria.HandlerTest do
  use ExUnit.Case

  describe "Telemetria.Handler.process_info/0" do
    test "returns keyword list with expected keys" do
      info = Telemetria.Handler.process_info()
      assert Keyword.keyword?(info)
      assert Keyword.has_key?(info, :status)
      assert Keyword.has_key?(info, :heap_size)
      assert Keyword.has_key?(info, :stack_size)
      assert Keyword.has_key?(info, :reductions)
      assert Keyword.has_key?(info, :schedulers)
      assert is_integer(info[:schedulers])
    end

    test "accepts a specific pid" do
      info = Telemetria.Handler.process_info(self())
      assert Keyword.keyword?(info)
      assert info[:status] in [:running, :waiting]
    end
  end
end

defmodule Telemetria.Handler.DefaultTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Telemetria.Handler.Default, as: DefaultHandler

  describe "handle_event/4" do
    test "logs telemetry event with default (non-smart) format" do
      Application.put_env(:telemetria, :smart_log, false)

      log =
        capture_log(fn ->
          DefaultHandler.handle_event(
            [:test, :handler, :event],
            %{consumed: 100},
            %{result: :ok, args: [x: 1], env: %{module: Foo, function: {:bar, 1}}},
            nil
          )
        end)

      assert log =~ "[:test, :handler, :event]"
      assert log =~ "result: :ok"
    end

    test "respects level filtering" do
      Application.put_env(:telemetria, :level, :warning)

      log =
        capture_log(fn ->
          DefaultHandler.handle_event(
            [:test, :filtered],
            %{consumed: 50},
            %{
              result: :ok,
              args: [],
              env: %{},
              context: %{options: [level: :debug]}
            },
            nil
          )
        end)

      refute log =~ "[:test, :filtered]"

      Application.put_env(:telemetria, :level, :debug)
    end
  end
end

defmodule Telemetria.Messenger.LoggerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Telemetria.Messenger.Logger, as: MLogger

  test "format/2 inspects the message" do
    result = MLogger.format(%{foo: :bar}, [])
    assert result =~ "foo"
    assert result =~ "bar"
  end

  test "debug/2 logs at debug level" do
    log = capture_log(fn -> MLogger.debug("debug msg", []) end)
    assert log =~ "debug msg"
  end

  test "info/2 logs at info level" do
    log = capture_log(fn -> MLogger.info("info msg", []) end)
    assert log =~ "info msg"
  end

  test "warning/2 logs at warning level" do
    log = capture_log(fn -> MLogger.warning("warn msg", []) end)
    assert log =~ "warn msg"
  end

  test "error/2 logs at error level" do
    log = capture_log(fn -> MLogger.error("error msg", []) end)
    assert log =~ "error msg"
  end
end

defmodule Telemetria.Backend.LoggerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Telemetria.Backend.Logger, as: BLogger

  test "entry/1 returns the block_id" do
    assert [:my, :event] == BLogger.entry([:my, :event])
  end

  test "update/2 returns the block_id unchanged" do
    assert :id == BLogger.update(:id, %{foo: :bar})
  end

  test "return/2 logs the event" do
    log =
      capture_log(fn ->
        BLogger.return([:test, :event], %{measurements: %{time: 42}, result: :ok})
      end)

    assert log =~ "[:test, :event]"
    assert log =~ "time: 42"
  end

  test "exit/1 returns :ok" do
    assert :ok == BLogger.exit(:anything)
  end

  test "reshape/1 returns updates unchanged" do
    data = %{a: 1, b: 2}
    assert ^data = BLogger.reshape(data)
  end
end
