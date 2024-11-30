defmodule Telemetria.Messenger.Test do
  use ExUnit.Case
  import Mox

  alias Telemetria.Messenger.Slack
  alias Test.Telemetria.Example

  setup_all do
    Application.put_env(:logger, :console, [], persistent: true)
    Application.put_env(:telemetria, :smart_log, false)
  end

  setup :verify_on_exit!

  @tag capture_log: true
  test "when specified, the messenger gets called" do
    Telemetria.Messenger.Mox
    |> allow(self(), Telemetria.Throttler.name())
    |> expect(:format, 1, fn map, opts -> Slack.format(map, opts) end)
    |> expect(:warning, 1, fn map, _opts ->
      assert %{
               description: "test.telemetria.example.third",
               fallback:
                 "test.telemetria.example.third\n&Test.Telemetria.Example.third/1\n/home/am/Proyectos/Elixir/telemetria/test/support/telemetria_tester.ex:37"
             } = map
    end)

    Example.third(42)
    Process.sleep(100)
  end
end
