# Optional Telemetria Support

To optionally include `telemetria` support to your library do the following.

## `mix.exs`

In your `mix.exs` file, specify the dependency as `optional: true`

```elixir
defp deps do
  ...
  {:telemetria, "~> 0.4", optional: true}
  ...
end
```

## Custom Module

Declare the custom module `MyApp.Telemetria` as shown below.

```elixir
defmodule MyApp.Telemetria do
  @moduledoc false

  @default_options [use: [], apply: [level: :info]]

  @all_options :telemetria
               |> Application.get_env(:applications, [])
               |> Keyword.get(:my_app, [])
  @options if @all_options == true,
             do: @default_options,
             else: Keyword.merge(@default_options, @all_options)

  @use @options != [] and match?({:module, Telemetria}, Code.ensure_compiled(Telemetria))

  defmacro __using__(opts \\ []),
    do: if(@use, do: quote(do: use(Telemetria, unquote(opts))), else: :ok)

  @spec use? :: boolean()
  def use?, do: @use

  @spec use!(module :: module(), opts :: keyword()) :: :ok | nil
  def use!(module, opts \\ true),
    do: if(Rambla.Telemetria.use?(), do: Module.put_attribute(module, :telemetria, opts))
end
```

## Conditional Include

In the module(s) where you want to optinally use `Telemetria`, add
`use MyApp.Telemetria`. All the attributes are to be now declared with

```elixir
if Rambla.Telemetria.use?(), do: @telemetria(level: :info)
```

or

```elixir
Rambla.Telemetria.use!(__MODULE__, level: :info)
```

That’s it. Enjoy.
