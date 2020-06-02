Application.ensure_started(:telemetry)

defmodule Test.Telemetria.S do
  use Boundary
  defstruct(foo: 42, bar: :baz)
end

defmodule Test.Telemetria.Example do
  @moduledoc false

  use Boundary, deps: [Telemetria], exports: []

  use Telemetria, action: :import

  defpt twice(a) do
    a * 2
  end

  deft sum_with_doubled(a1, a2) do
    a1 + twice(a2)
  end

  def half(a) do
    divider =
      t(fn
        a when is_integer(a) -> a / 2
        {a, _, _} -> a
        _ -> nil
      end)

    divider.(a)
  end

  def half_named(a) do
    t(&(&1 / 2), suffix: :foo).(a)
  end

  @telemetria true
  def annotated_1(foo), do: annotated_2(foo)
  @telemetria true
  def annotated_1(foo, bar), do: if(is_nil(bar), do: annotated_2(foo))

  def tmed, do: t(21 + 21)

  def tmed_do do
    t do
      84 / 2
    end
  end

  defp annotated_2(i \\ nil)

  @telemetria level: :warn
  defp annotated_2(i) when (is_integer(i) and i == 42) or is_nil(i), do: i || 42
  @telemetria level: :error
  defp annotated_2(_i), do: :foo

  deft guarded(a) when is_integer(a) and a > 0 do
    a + a
  end

  deft guarded(a) do
    a
  end

  @telemetria true
  def check_s(%Test.Telemetria.S{foo: 42}), do: {:ok, :foo}
  @telemetria true
  def check_s(%Test.Telemetria.S{bar: :baz}), do: {:ok, :bar}
  @telemetria true
  def check_s(any), do: {:error, any}
end
