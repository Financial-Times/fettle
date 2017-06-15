defmodule Fettle do
  @moduledoc """
  Direct API for health checks.

  Normally healthchecks are auto-configured via config.
  """

  def add(spec = %Fettle.Spec{}, {module, opts}) do
    raise ArgumentError, "Not implemented #{inspect spec} #{module} #{opts}"
  end

end

