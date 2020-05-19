import Config

config :telemetria,
  otp_app: :telemetria,
  events: []

if File.exists?("config/#{Mix.env()}.exs"), do: import_config("#{Mix.env()}.exs")
