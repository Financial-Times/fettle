# Fettle

Runs health-check functions periodically, and aggregates health status reports.

(AKA Elixir implementation of FT Health-Check standard).

> **fettle**
*noun* - "his best players were in fine fettle": shape, trim, fitness, physical fitness, health, state of health; condition, form, repair, state of repair, state, order, working order, way; informal: kilter; British informal: nick.

This library implents an asynchronous periodic check mechanism, and defines a way of configuring checks, and getting reports in a particular format. It
is designed for use with monitoring and dash-boards in a DevOps microservice environment.

Ships with the [FT Health Check V1](FTHealthcheckstandard.pdf) schema format for report generation, but the schema is configurable.

## See also 

* [`fettle_plug`](https://github.com/Financial-Times/fettle_plug) - integration with [Plug](https://github.com/elixir-lang/plug) to expose to HTTP.
* [`fettle_checks`](https://github.com/Financial-Times/fettle_checks) - a small library of commonly useful checks.

## Getting Started

### Installation

Add a dependency in your `mix.exs` config:

For the bleeding edge:

```elixir
def deps do
  [{:fettle, github: "Financial-Times/fettle"}]
end
```

Fettle is an OTP application, and in Elixir 1.4+, will be started with other applications through Elixir's auto-detection of OTP apps in dependencies.

### Defining checks

The [`fettle_checks`]() module provides pre-canned checks, but to write your own, implement a module with the `Fettle.Checker` `@behaviour` that runs a check, and returns a `Fettle.Check.Result` struct:

```elixir
defmodule MyCheck do
  @behaviour Fettle.Checker

  def check(arg) do
    case do_check(arg) do # assume do_check/1 does something useful!
        :ok -> Fettle.Check.Result.ok()
        {:error, message} -> Fettle.Check.Result.error(message)
    end
  end
```

Then configure this check, with some required metadata, in the `:fettle` configuration:

```elxir
config :fettle,
    system_code: "my_app", # required (for reports)
    checks: [
        {
            %{
                name: "my-check",
                panic_guide_url: "https://...",
                business_impact: "...",
                technical_summary: "..."
            },
            MyCheck, # name of our check module
            ["something"] # arguments to the module (optional)
        }
    ]
```

On application start-up, Fettle will start running your check, by default every 30 seconds, and you can retrieve the results using `Fettle.report/1`.

[`fettle_plug`](https://github.com/Financial-Times/fettle_plug) can then be used to expose the results over an HTTP end-point.

See module docs for full details.
