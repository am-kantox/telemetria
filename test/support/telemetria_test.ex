Application.ensure_started(:telemetry)

defmodule Test.Telemetria.Example do
  import Telemetria

  defpt(twice(a), do: a + a)
  deft(sum(a1, a2), do: a1 + twice(a2))

  defmacropt(half(a), do: quote(do: unquote(a) / 2))

  defmacrot mul(a1, a2) do
    ha2 = half(a2)

    quote do
      unquote(a1) * unquote(ha2)
    end
  end
end
