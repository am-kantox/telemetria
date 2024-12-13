ExUnit.start()

Mox.defmock(Telemetria.Messenger.Mox, for: Telemetria.Messenger)

if Telemetria.Backend.Telemetry in Telemetria.Application.backend(),
  do: Telemetria.Instrumenter.setup()
