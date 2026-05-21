defmodule Telemetria.MixProject do
  use Mix.Project

  @app :telemetria
  @version "0.25.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      xref: [exclude: []],
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_apps: [:nimble_options, :mix],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {Telemetria.Application, []},
      start_phases: [{:telemetry_setup, []}],
      registered: [Telemetria, Telemetria.Application]
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.0", optional: true},
      {:telemetry_poller, "~> 1.0", optional: true},
      {:opentelemetry_api, "~> 1.4", optional: true},
      # helpers
      {:estructura, "~> 1.6"},
      {:jason, "~> 1.0", optional: true},
      {:nimble_options, "~> 1.0"},
      # dev / test
      {:mox, "~> 1.0", only: [:dev, :test, :ci]},
      {:dialyxir, "~> 1.0", only: [:dev, :test, :ci], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
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
      files: ~w|stuff lib mix.exs README.md LICENSE|,
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
      assets: %{"stuff/img" => "assets"},
      extra_section: "GUIDES",
      extras:
        ["README.md" | Path.wildcard("stuff/*.md")] ++
          Path.wildcard("stuff/*.cheatmd"),
      groups_for_extras: [
        Cheatsheets: Path.wildcard("stuff/*.cheatmd")
      ],
      groups_for_modules: [
        # Telemetria
        # Telemetria.Backend
        Telemetry: [
          Telemetria.Backend.Telemetry,
          Telemetria.Handler,
          Telemetria.Handler.Default,
          Telemetria.Formatter,
          Telemetria.Telemetry
        ],
        OpenTelemetry: [
          Telemetria.Backend.OpenTelemetry
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
