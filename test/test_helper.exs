ExUnit.start()

Mox.defmock(Telemetria.Messenger.Mox, for: Telemetria.Messenger)
Telemetria.Instrumenter.setup()
