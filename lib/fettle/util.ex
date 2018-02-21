defmodule Fettle.Util do
  @moduledoc "Miscellaneous support functions"

  @doc "checks that a named module exists and complies with a behaviour"
  @spec check_module_complies!(
          module :: module,
          behaviour :: module,
          function :: {atom, non_neg_integer}
        ) :: module | no_return
  def check_module_complies!(module, behaviour, function = {name, arity})
      when is_atom(module) and is_atom(behaviour) and is_atom(name) and is_integer(arity) do
    case check_module_complies(module, behaviour, function) do
      {:error, message} -> raise ArgumentError, message
      ^module -> module
    end
  end

  @doc "checks that a named module exists and complies with a behaviour"
  @spec check_module_complies(
          module :: module,
          behaviour :: module,
          function :: {atom, non_neg_integer}
        ) :: module | {:error, String.t()}
  def check_module_complies(module, behaviour, {function, arity})
      when is_atom(module) and is_atom(behaviour) and is_atom(function) and is_integer(arity) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        case Kernel.function_exported?(module, function, arity) do
          true ->
            module

          false ->
            {:error,
             "Module #{module} does not comply to @behaviour #{behaviour} (no #{function}/#{arity} function)"}
        end

      {:error, error} ->
        {:error, "Cannot load module #{module}: #{error}"}
    end
  end

  def check_module_complies(module, _, _) when not is_atom(module) do
    raise ArgumentError, "Expected module to be an atom: #{inspect(module)}."
  end
end
