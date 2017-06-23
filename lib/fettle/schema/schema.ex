defmodule Fettle.Schema do
  @moduledoc "Behaviour for report generators."

  @type check :: {Fettle.Spec.t, Fettle.Checker.Result.t}
  @type report :: map | list

  @doc """
  Convert a list of check spec/result tuples into a particular output format, based on a list or a map.

  Typically the report will ultimately be serialized to JSON.
  """
  @callback to_schema(config :: Fettle.Config.t, checks :: [check]) :: report

  def complies(nil), do: {:error, nil}

  def complies(module) when is_atom(module) do
    Fettle.Util.check_module_complies(module, __MODULE__, {:to_schema, 2})
  end
end
