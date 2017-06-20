defmodule Fettle do
  @moduledoc """
  Direct API for health checks.

  Normally healthchecks are auto-configured via config.
  """
  alias Fettle.Schema

  @doc "Add a new health-check spec and module for periodic execution"
  def add(spec = %Fettle.Spec{}, module), do: add(spec, module, [])

  @doc "Add a new health-check spec and module with options for periodic execution"
  def add(spec = %Fettle.Spec{}, module, opts) when is_atom(module) and is_list(opts) do
    Fettle.ScoreBoard.new(spec)
    Fettle.RunnerSupervisor.start_check({spec, module, opts})
    :ok
  end

  @doc "Report in the current health check status."
  @spec report(schema_module :: atom | nil) :: Schema.report
  def report(schema_module \\ nil)

  def report(nil), do: Fettle.ScoreBoard.report()

  def report(schema_module) when is_atom(schema_module) do
    case Schema.complies(schema_module) do
      ^schema_module ->
        Fettle.ScoreBoard.report(schema_module) # use compliant schema
      {:error, err} -> raise ArgumentError, err
    end
  end

  @doc "Check if all tests are in a healthy state."
  def ok? do
    Fettle.ScoreBoard.ok?()
  end

end

