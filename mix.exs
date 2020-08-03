defmodule Telemetria.MixProject do
  use Mix.Project

  @app :telemetria
  @version "0.9.3"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: compilers(Mix.env()),
      start_permanent: Mix.env() == :prod,
      xref: [exclude: []],
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_deps: :transitive,
        plt_add_apps: [:nimble_options, :mix],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:logger, :telemetry],
      mod: {Telemetria.Application, []},
      start_phases: [{:telemetry_setup, []}],
      registered: [Telemetria, Telemetria.Application, Telemetria.Instrumenter]
    ]
  end

  defp deps do
    [
      {:boundary, "~> 0.4", runtime: false},
      {:telemetry, "~> 0.4"},
      {:telemetry_poller, "~> 0.5"},
      {:jason, "~> 1.0"},
      {:nimble_options, "~> 0.2"},
      # dev / test
      {:dialyxir, "~> 1.0.0", only: [:dev, :test, :ci]},
      {:credo, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:ex_doc, "~> 0.11", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp description do
    """
    The helper application that simplifies and standardizes telemetry usage.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|config stuff lib mix.exs README.md LICENSE|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["Kantox LTD"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "Telemetria",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/#{@app}-48x48.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      assets: "stuff/img",
      extras: ["README.md" | Path.wildcard("stuff/*.md")],
      groups_for_modules: [
        Defaults: [
          Telemetria.Handler
        ]
      ]
    ]
  end

  def compilers(:dev), do: [:boundary | Mix.compilers()]
  def compilers(_), do: Mix.compilers()

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
