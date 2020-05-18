defmodule TelemetriaTest do
  use ExUnit.Case
  doctest Telemetria

  test "greets the world" do
    assert Telemetria.hello() == :world
  end
end
