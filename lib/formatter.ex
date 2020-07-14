defmodule Telemetria.Formatter do
  @moduledoc """
  JSON formatter that is aware of `Telemetria` metadata.

  This code is gracefully stolen from internal Kantox Observability library.
  """

  @doc """
  Formats a log entry.
  """
  @spec format(Logger.level(), Logger.message(), Logger.Formatter.time(), Logger.metadata()) ::
          iodata()
  def format(level, message, timestamp, metadata) do
    {meta, metadata} = Keyword.pop(metadata, :__meta__, [])
    {measurements, metadata} = Keyword.pop(metadata, :__measurements__)
    {rest, metadata} = Keyword.pop(metadata, :__rest__, [])

    {otp_app, meta} = Keyword.pop(meta, :otp_app, :unknown)
    {inspect_opts, meta} = Keyword.pop(meta, :inspect_opts, [])
    {type, meta} = Keyword.pop(meta, :type, :log)
    {severity, meta} = Keyword.pop(meta, :severity, level)

    payload =
      [
        "@id": do_format(otp_app, inspect_opts),
        "@timestamp": do_format(timestamp, inspect_opts),
        "@type": do_format(type, inspect_opts),
        message: do_format(message, inspect_opts),
        severity: severity
      ] ++ meta ++ metadata

    payload = Keyword.update(payload, :context, rest, &Keyword.merge(rest, &1))

    payload =
      measurements
      |> is_nil()
      |> if(
        do: payload,
        else: Keyword.put(payload, :measurements, do_format(measurements, inspect_opts))
      )
      |> do_format(inspect_opts)
      |> Jason.encode_to_iodata!()

    [payload, ?\n]
  end

  @spec do_format(input :: term(), inspect_opts :: Inspect.Opts.t()) :: map()
  defp do_format(input, inspect_opts)

  defp do_format({date, {hour, min, sec, msec}}, _inspect_opts) do
    {date, {hour, min, sec}}
    |> NaiveDateTime.from_erl!({msec * 1_000, 3})
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp do_format(%DateTime{} = dt, _inspect_opts), do: DateTime.to_iso8601(dt)
  defp do_format(%Date{} = d, _inspect_opts), do: Date.to_iso8601(d)
  defp do_format(%Time{} = t, _inspect_opts), do: Time.to_iso8601(t)

  defp do_format(input, _inspect_opts) when is_binary(input), do: input
  defp do_format(input, _inspect_opts) when is_number(input), do: input
  defp do_format(input, _inspect_opts) when is_atom(input), do: Atom.to_string(input)

  defp do_format(input, _inspect_opts) when is_pid(input),
    do: input |> :erlang.pid_to_list() |> to_string()

  defp do_format(%{} = input, inspect_opts) do
    input
    |> Enum.map(fn {key, value} -> {key, do_format(value, inspect_opts)} end)
    |> Map.new()
  end

  defp do_format(input, inspect_opts) when is_list(input) do
    if Keyword.keyword?(input),
      do: input |> Map.new() |> do_format(inspect_opts),
      else: input |> Enum.map(&do_format(&1, inspect_opts))
  end

  defp do_format(input, inspect_opts) when is_tuple(input) do
    input
    |> Tuple.to_list()
    |> do_format(inspect_opts)
  end

  # [TODO] maybe `if Enumerable.impl_for(input) do`
  defp do_format(input, inspect_opts), do: inspect(input, inspect_opts)
end
