defmodule Test.Telemetria.S do
  @moduledoc false
  defstruct(foo: 42, bar: :baz)

  def allow?(arg), do: arg == :persistent_term.get(__MODULE__, :forty_two)
end

defmodule Test.Telemetria.Example do
  @moduledoc false

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
  @telemetria if: Application.compile_env(:telemetria, :annotated_1?, true)
  def annotated_1(foo, bar), do: if(is_nil(bar), do: annotated_2(foo))

  def tmed, do: t(21 + 21)

  def tmed_do do
    t do
      84 / 2
    end
  end

  @telemetria level: :debug
  defp annotated_2(nil), do: 0

  @telemetria level: :warning,
              transform: [
                args: {__MODULE__, :transform_args},
                result: &__MODULE__.transform_result/1
              ]
  defp annotated_2(i) when (is_integer(i) and i == 42) or is_nil(i), do: i || 42

  @telemetria level: :error, if: &Test.Telemetria.S.allow?/1
  defp annotated_2(i), do: i && :forty_two

  @telemetria level: :info, group: :some_group, locals: [:i]
  def annotated_3(i \\ nil)
  def annotated_3(nil), do: 0
  def annotated_3(i) when is_binary(i), do: String.to_integer(i)
  def annotated_3(i) when is_integer(i), do: i

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

  #############################################################################
  def transform_args(args), do: inspect(args)

  def transform_result(result), do: inspect(result)
end
