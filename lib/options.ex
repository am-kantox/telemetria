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

  @spec mf(mf_tuple) :: {:ok, mf_tuple} | {:error, binary()} when mf_tuple: {module(), atom()}
  def mf({mod, fun}) do
    if match?({:module, ^mod}, Code.ensure_compiled(mod)) && mod.__info__(:functions)[fun] == 4,
      do: {:ok, {mod, fun}},
      else:
        {:error, "Expected MF pair returning a function of arity 4, got #{inspect({mod, fun})}."}
  end

  @schema [
    otp_app: [
      type: :atom,
      default: :telemetria,
      doc: "OTP application this telemetry is attached to."
    ],
    enabled: [
      type: :boolean,
      doc: "Specifies whether telemetry should be enabled.",
      default: true
    ],
    smart_log: [
      type: :boolean,
      doc: "Log format to use; when true, custom json would be used",
      default: false
    ],
    applications: [
      type: :keyword_list,
      doc: "List the applications to enable Telemetria support for, with parameters",
      default: []
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
      type: {:custom, Telemetria.Options, :mf, []},
      default: {Telemetria.Handler.Default, :handle_event},
      doc: "Event handler for this application’s telemetry events. Arity must be 4."
    ],
    polling: [
      type: :keyword_list,
      default: [enabled: false, flush: 5_000, poll: 5_000],
      keys: [
        enabled: [
          type: :boolean,
          doc: "Specifies whether polling should be enabled.",
          default: true
        ],
        flush: [
          type: :non_neg_integer,
          doc: "Flush interval.",
          default: 5_000
        ],
        poll: [
          type: :non_neg_integer,
          doc: "Poll interval.",
          default: 5_000
        ]
      ]
    ]
  ]

  @doc false
  @spec schema :: NimbleOptions.schema()
  def schema, do: @schema

  @spec initial :: keyword()
  def initial,
    do: NimbleOptions.validate!(Application.get_all_env(:telemetria), Telemetria.Options.schema())
end

NimbleOptions.validate!(Application.get_all_env(:telemetria), Telemetria.Options.schema())
