defmodule Fettle do
  @moduledoc """
  Direct API for health checks.

  Normally healthchecks are auto-configured via config.
  """
  alias Fettle.Schema

  def add(spec = %Fettle.Spec{}, {module, opts}) do
    Fettle.ScoreBoard.new(spec)
    Fettle.RunnerSupervisor.start_check({spec, module, opts})
  end

  @spec report(schema_module :: atom | nil) :: Schema.Report.t
  def report(schema_module \\ nil)

  def report(nil), do: Fettle.ScoreBoard.report()

  def report(schema_module) when is_atom(schema_module) do
    case Schema.complies(schema_module) do
      ^schema_module ->
        Fettle.ScoreBoard.report(schema_module) # use compliant schema
      {:error, err} -> raise ArgumentError, err
    end
  end

end

