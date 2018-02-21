defmodule Fettle do
  @moduledoc """
  Dynamic API for configuring health checks, and interacting with health state.

  Normally healthchecks are auto-configured via config, but can be added at any time,
  which may be useful in certain circumstances.

  This module also provides functions for obtaining the current state of checks,
  either in a form supported by a `Fettle.Schema` module, or a simple boolean.
  """

  alias Fettle.Schema

  @doc "Add a new health-check spec and module for periodic execution"
  def add(spec = %Fettle.Spec{}, module), do: add(spec, module, [])

  @doc "Add a new health-check spec and module and arguments for periodic execution"
  def add(spec = %Fettle.Spec{}, module, args) when is_atom(module) and is_list(args) do
    Fettle.ScoreBoard.new(spec)
    Fettle.RunnerSupervisor.start_check({spec, module, args})
    :ok
  end

  @doc "Report in the current health check status."
  @spec report(schema_module :: atom | nil) :: Schema.report()
  def report(schema_module \\ nil)

  def report(nil), do: Fettle.ScoreBoard.report()

  def report(schema_module) when is_atom(schema_module) do
    case Schema.complies(schema_module) do
      ^schema_module ->
        # use compliant schema
        Fettle.ScoreBoard.report(schema_module)

      {:error, err} ->
        raise ArgumentError, err
    end
  end

  @doc "Check if all tests are in a healthy state."
  def ok? do
    Fettle.ScoreBoard.ok?()
  end
end
