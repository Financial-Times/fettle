defmodule Fettle.Schema do
  @moduledoc "Behaviour for report generators."

  @type check :: {Fettle.Spec.t, Fettle.Checker.Result.t}
  @type report :: map | list

  @doc """
  Convert a list of check spec/result tuples into a particular output format, based on a list or a map.

  Typically the report will be then serialized to JSON.
  """
  @callback to_schema(config :: Fettle.Config.t, checks :: [check]) :: report

  def complies(nil), do: {:error, nil}

  def complies(module) when is_atom(module) do
    loaded_exported = {
      Code.ensure_loaded(module),
      function_exported?(module, :to_schema, 2)
    }

    case loaded_exported do
      {{:module, _module}, true} ->
        :ok
      {{:error, err}, _} ->
        {:error, "Unable to load Schema #{module} - #{inspect err}"}
      {{:module, _module}, false} ->
        {:error, "#{module} does not comply to @behaviour #{__MODULE__}"}
    end
  end
end
