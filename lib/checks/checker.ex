defmodule Fettle.Checker do
  @moduledoc "The checker protocol to be implemented by healthcheck modules"

  alias Fettle.Checker.Result

  @callback check(args :: any) :: Result.t

end
