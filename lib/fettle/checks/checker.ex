defmodule Fettle.Checker do
  @moduledoc """
  The checker behaviour to be implemented by healthcheck modules.

  The `check/1` function will receive the argument configured using
  the check options under the `:args` key:

  ```
  {
    %{
      name: "check name",
      ...
    },
    CheckerModule,
    [args: %{a: 1, b: 2}] # map will be supplied as argument to checker/1
  }
  ```

  module will be called as:

  ```
  CheckModule.check(%{a: 1, b: 2})
  ```

  Checks must complete within the timeout period configured for the check
  (or globally in config), and return a `Fettle.Checker.Result`.
  """

  alias Fettle.Checker.Result

  @callback check(args :: any) :: Result.t

end
