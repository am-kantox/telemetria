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
    {telemetria, metadata} = Keyword.pop(metadata, :telemetría, [])
    {process_info, metadata} = Keyword.pop(metadata, :process_info, [])

    {otp_app, telemetria} = Keyword.pop(telemetria, :otp_app, :unknown)
    {inspect_opts, telemetria} = Keyword.pop(telemetria, :inspect_opts, [])
    {type, telemetria} = Keyword.pop(telemetria, :type, :log)
    {severity, telemetria} = Keyword.pop(telemetria, :severity, level)

    payload =
      ([
         "@id": otp_app,
         "@timestamp": timestamp,
         "@type": type,
         message: message,
         severity: severity,
         telemetria: telemetria,
         process_info: process_info
       ] ++ metadata)
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

  defp do_format(input, _inspect_opts) when is_reference(input),
    do: input |> :erlang.ref_to_list() |> to_string()

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
