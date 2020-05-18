defmodule Mix.Tasks.Compile.Telemetria do
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  use Boundary, deps: [], exports: []
  use Mix.Task.Compiler

  @moduledoc """
  Allows compile-time telemetry events definition.

  ## Usage

  You need to include the compiler in `mix.exs`:

  ```
  defmodule MySystem.MixProject do
    # ...

    def project do
      [
        compilers: [:telemetria] ++ Mix.compilers(),
        # ...
      ]
    end

    # ...
  end
  ```
  """

  @impl Mix.Task.Compiler
  def run(argv) do
    {:module, _} = Application.ensure_started(:telemetry)
    Mix.Task.Compiler.after_compiler(:app, &after_compiler(&1, argv))
    {:ok, []}
  end

  defp after_compiler({:error, _} = status, _argv), do: status

  defp after_compiler({status, diagnostics}, _argv) when status in [:ok, :noop] do
    app_name = Keyword.fetch!(Mix.Project.config(), :app)

    # We're reloading the app to make sure we have the latest version. This fixes potential stale state in ElixirLS.
    Application.unload(app_name)
    Application.load(app_name)

    Mix.Shell.IO.info("Telemetry events registered: ...")
    {status, diagnostics}
  end
end
