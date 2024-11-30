defmodule Telemetria.Messenger.Slack do
  @moduledoc false

  @behaviour Telemetria.Messenger

  @impl true
  # %{
  #   args: [a: 42],
  #   env: %{
  #     function: {:half, 1},
  #     line: 23,
  #     module: Test.Telemetria.Example,
  #     file: "/home/am/Proyectos/Elixir/telemetria/test/support/telemetria_tester.ex"
  #   },
  #   context: [],
  #   result: 21.0,
  #   locals: [],
  #   measurements: %{
  #     system_time: [
  #       system: 1732885662078938716,
  #       monotonic: -576460750195561,
  #       utc: ~U[2024-11-29 13:07:42.078940Z]
  #     ],
  #     consumed: 3336
  #   },
  #   telemetria_group: :default
  # }
  def format(message, opts) do
    with {event, message} <- Map.pop(message, :event),
         {%{function: {f, a}} = env, message} <- Map.pop(message, :env),
         {level, message} <-
           Map.pop_lazy(message, :level, fn -> Keyword.get(opts, :level, :info) end),
         {icon, message} <- Map.pop(message, :icon, slack_icon(level)) do
      title = Enum.join(event, ".")

      pretext =
        env.module
        |> Function.capture(f, a)
        |> inspect()
        |> Kernel.<>("\n#{env.file}:#{env.line}")

      fields =
        message
        |> Estructura.Flattenable.flatten(jsonify: true)
        |> Enum.map(fn {k, v} ->
          %{
            title: k,
            value: v,
            short: not is_binary(v) or String.length(v) < 32
          }
        end)

      attachments =
        %{
          color: slack_color(level),
          fields: fields,
          mrkdwn_in: ["title", "text", "pretext"]
        }
        |> Map.merge(%{pretext: "```\n" <> pretext <> "\n```"})

      fallback =
        [title, pretext]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      %{
        description: title,
        emoji_icon: icon,
        fallback: fallback,
        mrkdwn: true,
        attachments: [attachments]
      }
    end
  end

  Enum.each(~w|debug info warning error|a, fn level ->
    @impl true
    def unquote(level)(message, opts),
      do: post(unquote(level), message, opts)
  end)

  defp post(level, message, opts) do
    json =
      message
      |> put_in([:emoji_icon], slack_icon(level))
      |> put_in([:attachments, Access.all(), :color], slack_color(level))
      |> Jason.encode!()
      |> :erlang.binary_to_list()

    url = Keyword.fetch!(opts, :url)

    :httpc.request(:post, {to_charlist(url), [], ~c"application/json", json}, [], [])
  end

  defp slack_icon(:debug), do: ":speaker:"
  defp slack_icon(:info), do: ":information_source:"
  defp slack_icon(:warn), do: ":warning:"
  defp slack_icon(:warning), do: slack_icon(:warn)
  defp slack_icon(:error), do: ":exclamation:"

  defp slack_icon(level) when is_binary(level),
    do: level |> String.to_existing_atom() |> slack_icon()

  defp slack_icon(_), do: slack_icon(:info)

  defp slack_color(:debug), do: "#AAAAAA"
  defp slack_color(:info), do: "good"
  defp slack_color(:warn), do: "#FF9900"
  defp slack_color(:warning), do: slack_color(:warn)
  defp slack_color(:error), do: "danger"
end
