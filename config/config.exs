import Config

config :telemetria,
  backend: :telemetry,
  purge_level: :debug,
  level: :info,
  events: [
    [:test, :telemetria, :example, :twice],
    [:test, :telemetria, :example, :sum_with_doubled],
    [:test, :telemetria, :example, :half],
    [:test, :telemetria, :example, :half_named, :foo],
    [:test, :telemetria, :example, :third],
    [:test, :telemetria, :example, :tmed],
    [:test, :telemetria, :example, :tmed_do],
    [:test, :telemetria, :example, :guarded],
    [:test, :telemetria, :example, :annotated_1],
    [:test, :telemetria, :example, :annotated_2],
    [:test, :telemetria, :example, :annotated_3],
    [:test, :telemetria, :example, :check_s]
  ],
  throttle: %{some_group: {1_000, :last}}

# config :logger, :default_formatter,
#   format: {Telemetria.Formatter, :format},
#   metadata: :all

if Mix.env() == :test do
  config :telemetria, :messenger_channels, %{mox: {:mox, []}}
end
