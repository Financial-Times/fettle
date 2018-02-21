# Fettle

Runs health-check functions periodically, and aggregates health status reports.

(AKA Elixir implementation of FT Health-Check standard).

[![Hex pm](http://img.shields.io/hexpm/v/fettle.svg?style=flat)](https://hex.pm/packages/fettle) [![Inline docs](http://inch-ci.org/github/Financial-Times/fettle.svg)](http://inch-ci.org/github/Financial-Times/fettle) [![Build Status](https://travis-ci.org/Financial-Times/fettle.svg?branch=master)](https://travis-ci.org/Financial-Times/fettle)

> **fettle**
*noun* - "his best players were in fine fettle": shape, trim, fitness, physical fitness, health, state of health; condition, form, repair, state of repair, state, order, working order, way; informal: kilter; British informal: nick.

This library implents an asynchronous periodic check mechanism, and defines a way of configuring checks, and getting reports in a particular format. It is intended for use with monitoring and dashboards.

Ships with the [FT Health Check V1](https://github.com/Financial-Times/fettle/blob/master/FTHealthcheckstandard.pdf) schema format for report generation, but the schema is configurable.

## See also 

* [`fettle_plug`](https://github.com/Financial-Times/fettle_plug) - integration with [Plug](https://github.com/elixir-lang/plug) to expose to HTTP.
* [`fettle_checks`](https://github.com/Financial-Times/fettle_checks) - a small library of commonly useful checks.

## Getting Started

### Installation

Add a dependency in your `mix.exs` config:

```elixir
def deps do
  [
    {:fettle, "~> 0.2"}
  ]
end
```

For the bleeding edge:

```elixir
def deps do
  [
    {:fettle, github: "Financial-Times/fettle"}
  ]
end
```

### Starting

Add `Fettle.Supervisor` to your supervision tree<sup>1</sup>, e.g. in your `Application.start/2`:

```elixir
def start(_type, _args) do
    children = [
        {Fettle.Supervisor, []},
        ...
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
end
```

or otherwise call `Fettle.Supervisor.start_link/1`.

By default Fettle will load configuration from the `:fettle` application config key, the minimum 
required configuration for start-up is:

```elixir
config :fettle,
    system_code: "my_app"
```

where `system_code` is a code used in reports; see below for other options.

* [1] - this changed in v0.2.0 - was auto-starting OTP application.
### Defining checks

The [`fettle_checks`](https://github.com/Financial-Times/fettle_checks) module provides pre-canned checks, but to write your own, implement a module with the `Fettle.Checker` `@behaviour` that runs a check, and returns a `Fettle.Check.Result` struct:

```elixir
defmodule MyCheck do
  @behaviour Fettle.Checker

  def check(args) do
    case do_check(args) do  # assume do_check/1 does something useful!
      :ok -> 
        Fettle.Checker.Result.ok()
      {:error, message} -> 
        Fettle.Checker.Result.error(message)
    end
  end
end
```

Then configure this check, with some required metadata, in the `:fettle` configuration:

```elixir
config :fettle,
    system_code: "my_app", # required (for reports)
    checks: [
        %{
            name: "my-check",
            panic_guide_url: "https://...",
            business_impact: "...",
            technical_summary: "..."
            checker: MyCheck, # name of our check module
            args: "url_or_something" # arguments to the checker module (optional)
        },
        ...
    ]
```

On start-up, Fettle will start running your check, by default every 30 seconds, and you can retrieve the results using `Fettle.report/1`.

[`fettle_plug`](https://github.com/Financial-Times/fettle_plug) can then be used to expose the results over an HTTP end-point.

See module docs for full details.
