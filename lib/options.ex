defmodule Telemetria.Options do
  @moduledoc false

  use Boundary, deps: [], exports: []

  @spec list([any()], [{module(), atom()} | {module(), atom(), [any()]}]) ::
          {:ok, [any()]} | {:error, binary()}
  @doc false
  def list(values, checkers) do
    values
    |> Enum.all?(fn value ->
      Enum.any?(checkers, fn
        {m, f} -> apply(m, f, [value])
        {m, f, args} -> apply(m, f, [value | args])
      end)
    end)
    |> if(
      do: {:ok, values},
      else: {:error, "Expected list of elements of specified types, got #{inspect(values)}."}
    )
  end

  @schema [
    otp_app: [
      type: :atom,
      default: :telemetria,
      doc: "OTP application this telemetry is attached to."
    ],
    json_config_path: [
      type: :string,
      default: Path.join(["config", ".telemetria.config.json"]),
      doc: "Relative path to JSON config"
    ],
    events: [
      type:
        {:custom, Telemetria.Options, :list,
         [[{Telemetria.Options, :list, [[{Kernel, :is_atom, []}]]}]]},
      default: [],
      doc: """
      The application-specific events.

      See `:telemetry.event_prefix/0` and `:telemetry.event_name/0`.
      """
    ],
    handler: [
      type: :mfa,
      default: {Telemetria.Handler, :handle_event, 4},
      doc: "Event handler for this application’s telemetry events. Arity must be 4."
    ]
  ]

  @doc false
  @spec schema :: NimbleOptions.schema()
  def schema, do: @schema
end

NimbleOptions.validate!(Application.get_all_env(:telemetria), Telemetria.Options.schema())
