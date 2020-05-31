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

* **`0.5.1`** —
  * [ENH] add result of underlying call to metric
  * [ENH] decrease an amount of garbage returned from caller context
* **`0.5.0`** —
  * [ENH] annotation `@telemetria true` as a synonym to `deft/2`
  * [FIX] polling is off by default
* **`0.4.0`** —
  * [ENH] default polling of system / vm states for free
  * [ENH] starting in phases ensuring proper instrumenter setup
* **`0.3.0`** —
  * [ENH] no need for any config in any environment
  * [BUG] proper handling of guards in compiler, correct event names

## [Documentation](https://hexdocs.pm/telemetria).

