defmodule Fettle.Checker do
  @moduledoc """
  The behaviour to be implemented by healthcheck modules.

  The `check/1` function will receive the argument configured using
  the `args` key in the check config, e.g.

  ```
    config :fettle,
      ...
      checks: [
        [
          name: "check name",
          ...
          checker: CheckerModule,
          args: [a: 1, b: 2] # keyword list will be supplied as argument to checker/1
        ],
        ...
      ]
  }
  ```

  The hyperthetical `CheckerModule` module will be called as:

  ```
  CheckerModule.check(a: 1, b: 2)
  ```

  Checks must complete within the timeout period configured for the check
  (or globally in check config), and return a `Fettle.Checker.Result`.
  """

  alias Fettle.Checker.Result

  @callback check(args :: any) :: Result.t

end
