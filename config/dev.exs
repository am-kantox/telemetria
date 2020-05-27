import Config

config :telemetria,
  events: [
    [:test, :telemetria, :example, :twice],
    [:test, :telemetria, :example, :sum_with_doubled],
    [:test, :telemetria, :example, :guarded]
  ]
