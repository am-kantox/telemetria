defmodule Telemetria.ConfigProvider do
  @moduledoc false

  use Boundary, deps: [Telemetria.Mix.Events], exports: []

  alias Telemetria.Mix.Events

  @behaviour Config.Provider

  @impl Config.Provider
  def init(path) when is_binary(path), do: path

  @impl Config.Provider
  def load(config, path) do
    {:ok, _} = Application.ensure_all_started(:jason)

    json = path |> File.read!() |> Jason.decode!()

    Config.Reader.merge(
      config,
      telemetria: [
        otp_app: json["otp_app"],
        events: json["events"]
      ]
    )
  end

  @spec json_config!(binary() | nil) :: keyword()
  def json_config!(path \\ nil) do
    path = guess_config_path(path)

    path
    |> File.exists?()
    |> if do
      with {:ok, json} <- File.read(path) do
        json
        |> Jason.decode!()
        |> maybe_atomize()
        |> Map.to_list()
      end
    end
    |> Kernel.||([])
  end

  defp guess_config_path(path) when is_binary(path), do: path
  defp guess_config_path(_), do: Events.json_config_path()

  defp maybe_atomize(v) when is_binary(v), do: String.to_atom(v)
  defp maybe_atomize({k, v}), do: {maybe_atomize(k), maybe_atomize(v)}
  defp maybe_atomize(v) when is_list(v), do: Enum.map(v, &maybe_atomize/1)
  defp maybe_atomize(v) when is_map(v), do: Enum.into(v, %{}, &maybe_atomize/1)
  defp maybe_atomize(v), do: v
end
