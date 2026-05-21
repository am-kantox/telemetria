defmodule Telemetria.ThrottlerTest do
  use ExUnit.Case

  alias Telemetria.Throttler

  describe "name/0" do
    test "returns a module name based on otp_app" do
      name = Throttler.name()
      assert is_atom(name)
      assert name |> to_string() |> String.contains?("Throttler")
    end
  end

  describe "execute/2 with :none group (immediate)" do
    @tag capture_log: true
    test "fires event immediately for unconfigured group" do
      event = [:test, :throttler, :immediate]
      parent = self()

      :telemetry.attach(
        "throttler-test-immediate",
        event,
        fn ev, measurements, _metadata, _config ->
          send(parent, {:telemetry_event, ev, measurements})
        end,
        nil
      )

      Throttler.execute(
        nil,
        {event, %{consumed: 10, consumed_ns: 10_000},
         %{result: :ok, args: [], env: %{}, context: []}, nil, nil, event}
      )

      assert_receive {:telemetry_event, ^event, %{consumed: 10}}, 500
    after
      :telemetry.detach("throttler-test-immediate")
    end
  end

  describe "execute/2 with :last throttle group" do
    @tag capture_log: true
    test "throttled group collects events in configured window" do
      event = [:test, :throttler, :throttled]
      parent = self()

      :telemetry.attach(
        "throttler-test-throttled",
        event,
        fn ev, measurements, _metadata, _config ->
          send(parent, {:telemetry_event, ev, measurements})
        end,
        nil
      )

      for i <- 1..3 do
        Throttler.execute(
          :some_group,
          {event, %{consumed: i, consumed_ns: i * 1_000},
           %{result: i, args: [], env: %{}, context: []}, nil, nil, event}
        )
      end

      # Wait for the throttle window (1000ms configured in config.exs)
      assert_receive {:telemetry_event, ^event, _}, 1_500
    after
      :telemetry.detach("throttler-test-throttled")
    end
  end
end
