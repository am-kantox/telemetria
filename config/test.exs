import Config

config :telemetria,
  events: [
    [:test, :telemetria, :example, :twice],
    [:test, :telemetria, :example, :sum_with_doubled],
    [:test, :telemetria, :example, :half],
    [:test, :telemetria, :example, :half_named, :foo],
    [:test, :telemetria, :example, :tmed],
    [:test, :telemetria, :example, :tmed_do]
  ]
