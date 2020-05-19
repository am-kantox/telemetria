Application.ensure_started(:telemetry)

defmodule Test.Telemetria.Example do
  use Boundary, deps: [Telemetria], exports: []

  import Telemetria

  defpt twice(a) do
    a * 2
  end

  deft sum_with_doubled(a1, a2) do
    a1 + twice(a2)
  end
end
