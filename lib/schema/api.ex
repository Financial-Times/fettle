defmodule Fettle.Schema.Api do
  @moduledoc "Behaviour for report generators."

  @type check :: {Fettle.Spec.t, Fettle.Checker.Result.t}
  @type report :: map | list

  @doc """
  Convert a list of check spec/result tuples into a particular output format, based on a list or a map.

  Typically the report will be then serialized to JSON.
  """
  @callback to_schema(config :: Fettle.Config.t, checks :: [check]) :: report
end
