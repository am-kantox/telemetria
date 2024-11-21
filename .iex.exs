global_settings = "~/.iex.exs"
if File.exists?(global_settings), do: Code.require_file(global_settings)

Application.put_env(:elixir, :ansi_enabled, true)

IEx.configure(
  # inspect: [limit: :infinity],
  colors: [
    eval_result: [:cyan, :bright],
    eval_error: [[:red, :bright, "\n▶▶▶\n"]],
    eval_info: [:yellow, :bright],
    syntax_colors: [
      number: :red,
      atom: :blue,
      string: :green,
      boolean: :magenta,
      nil: :magenta,
      list: :white
    ]
  ],
  default_prompt:
    [
      :blue,
      "%prefix",
      :cyan,
      "|⌚|",
      :blue,
      "%counter",
      " ",
      :cyan,
      "▶",
      :reset
    ]
    |> IO.ANSI.format()
    |> IO.chardata_to_string()
)

Logger.configure(default_formatter: [metadata: :all, format: {Telemetria.Formatter, :format}])
Application.put_env(:telemetria, :smart_log, true)
