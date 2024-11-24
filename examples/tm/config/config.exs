import Config

config :telemetria,
  purge_level: :debug,
  level: :info,
  events: [
    [:tm, :f_to_c]
  ],
  throttle: %{some_group: {1_000, :last}}
