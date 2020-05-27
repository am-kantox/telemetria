# Telemetría

#### ![Test](https://github.com/am-kantox/telemetria/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/telemetria/workflows/Dialyzer/badge.svg)  The helper application that simplifies and standardizes telemetry usage.

## Installation

```elixir
def project do
  [
    compilers: [:telemetria | Mix.compilers()]
  ]
end

def deps do
  [
    {:telemetria, "~> 0.1"}
  ]
end
```

## Changelog

* **`0.3.0`** —
  * [ENH] no need for any config in any environment
  * [BUG] proper handling of guards in compiler, correct event names

## [Documentation](https://hexdocs.pm/telemetria).

