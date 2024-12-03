defmodule Telemetria.Messenger do
  @moduledoc """
  The helper allowing quick sending of the telemetry events to the messenger.
  """

  @typedoc "The type of the message the messenger is to process and send"
  @type message :: %{
          required(atom()) => term()
        }

  @doc "The formatter of the incoming message, producing the binary to be sent over the wire"
  @callback format(message(), keyword()) :: message() | String.t()

  @doc "The actual implementation of the message sending (`debug` level)"
  @callback debug(message(), keyword()) :: {:ok, term()} | {:error, term()}

  @doc "The actual implementation of the message sending (`info` level)"
  @callback info(message(), keyword()) :: {:ok, term()} | {:error, term()}

  @doc "The actual implementation of the message sending (`warning` level)"
  @callback warning(message(), keyword()) :: {:ok, term()} | {:error, term()}

  @doc "The actual implementation of the message sending (`error` level)"
  @callback error(message(), keyword()) :: {:ok, term()} | {:error, term()}

  @optional_callbacks format: 2

  @implementation Telemetria.Messenger.Logger

  @doc "Routes the message to the configured messenger(s)"
  @spec post(message() | String.t(), impl :: atom() | module(), opts :: keyword()) ::
          {:ok, term()} | {:error, term()}
  def post(message, impl \\ @implementation, opts \\ [])

  def post(%{} = message, impl, opts) do
    impl = fix_impl_name(impl)

    message =
      if function_exported?(impl, :format, 2),
        do: impl.format(message, opts),
        else: inspect(message, opts)

    do_post(message, impl, opts)
  rescue
    e in KeyError ->
      require Logger

      message =
        """
        One or more required options were missing for the call to the messenger implementation
        in `telemetría` module attribute (or global config.)

        For now this is rescued and application can continue, but messenging from telemetria won’t work.

        Error: #{e.message}.
        """

      Logger.error(message)

    e in RuntimeError ->
      require Logger

      message =
        """
        The unexpected runtime error occured. Usually it means the config in `runtime.exs`
        is diverged from what `telemetría` compliler saw. Please move all the config to the
        compile-time configurations files since `telemetría` needs them during a compilation stage.

        Error: #{e.message}
        """

      Logger.error(message)
  end

  def post(message, impl, opts) when is_binary(message),
    do: do_post(message, impl, opts)

  defp do_post(message, impl, opts) do
    impl = fix_impl_name(impl)
    {level, opts} = Keyword.pop(opts, :level, :info)
    apply(impl, level, [message, opts])
  end

  @spec fix_impl_name(atom()) :: module()
  defp fix_impl_name(true), do: fix_impl_name(@implementation)

  defp fix_impl_name(impl) do
    case to_string(impl) do
      "Elixir." <> _ -> impl
      _ -> Module.concat([Telemetria, Messenger, impl |> to_string() |> Macro.camelize()])
    end
  end
end
