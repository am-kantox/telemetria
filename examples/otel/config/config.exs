import Config

config :telemetria,
  backend: Telemetria.Backend.OpenTelemetry,
  purge_level: :debug,
  level: :info,
  events: [
    [:tm, :f_to_c],
    [:tm, :do_f_to_c]
  ],
  throttle: %{some_group: {1_000, :last}}

# create a slack app and put URL here
# messenger_channels: %{slack: {:slack, url: ""}}

config :opentelemetry,
  traces_exporter: :none

config :opentelemetry, :processors, [
  {:otel_simple_processor, %{}}
]
