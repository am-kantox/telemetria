defmodule Tm.MixProject do
  use Mix.Project

  def project do
    [
      app: :tm,
      version: "0.1.0",
      elixir: "~> 1.17",
      compilers: [:telemetria | Mix.compilers()],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetria, path: "../.."}
    ]
  end
end
