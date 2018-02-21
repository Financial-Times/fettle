defmodule Fettle.Checker do
  @moduledoc """
  The behaviour to be implemented by healthcheck modules.

  The `check/1` function should return either a `Fettle.Checker.Result`, or a tuple
  with `Fettle.Checker.Result` as the first element, and the second element some state
  to maintain for the next run. An optional `init/1` function can set up an initial
  state based on config.

  ## Stateless checker modules

  Without an `init/1` function, the `check/1` module will receive the value of the `args`
  option from the check configuration, and should return a `Fettle.Checker.Result` depending
  on the result of running its check:

  e.g. assuming this configuration:

  ```elixir
    config :fettle,
      ...
      checks: [
        [
          name: "check name",
          ...
          checker: MySimpleChecker,
          args: [a: 1, b: 2] # will be supplied as argument to check/1
        ],
        ...
      ]
  }
  ```
  If the `MySimpleChecker` module is defined thus:

  ```elixir
  defmodule MySimpleChecker do
    use Fettle.Checker # convenience to get Result import and @behaviour

    def check(args) do
      %Result{} = do_some_check(args[:a], args[:b])
    end
  end
  ```

  the module will be called each time with the value of `args` from config, and will
  return a `Fettle.Checker.Result` corresponding to the check result.

  In addition, an `init/1` function may be defined to transform the `args` state
  for the `check/1` function.

  ## Stateful checkers

  Checker modules may optionally maintain state between calls, allowing them to perform
  flap detection or other functionality.

  If the `init/1` function is implemented, it will receive the argument configured
  using the `args` key in the check config; the function can then return the
  initial state to be passed to the `check/1` function. The `check/1` function can
  update this state and return it along with the `Fettle.Checker.Result`.

  e.g. assuming configuration:

    ```elixir
    config :fettle,
      ...
      checks: [
        [
          name: "check name",
          ...
          checker: NStrikesChecker,
          args: [a: 1, b: 2, limit: 3]
        ],
        ...
      ]
  }
  ```

  We could implement a module that required *n* failures before reporting an error state, by
  maintaining the number of consecutive failures thus:

  ```elixir
  defmodule NStrikesChecker do
    use Fettle.Checker

    def init(args) do
      Enum.into(Keyword.merge([limit: 3], args), %{failure_count: 0})
    end

    def check(state = %{a: a, b: b, limit: limit, failure_count: failure_count}) do

      result = %Result{status: status} = do_some_check(a, b)

      case {status, failure_count + 1} do
        {:ok, _} ->
          {result, %{state | failure_count: 0}}
        {_status, count} where count >= limit ->
          {result, %{state | failure_count: count}}
        {_status, count} ->
          {Result.ok(), %{state | failure_count: count}}
      end
    end
  end
  ```

  The `NStrikesChecker` module will be initialized using:

  ```
  state1 = NStrikesChecker.init(a: 1, b: 2, limit: 3)
  ```

  and then scheduled to be called with the state `state1` to actually perform the check:

  ```
  {result = %Result{}, state2} = NStrikesChecker.check(state1)
  ```

  the check returns a tuple with the `%Fettle.Checker.Result{}` and the updated state,
  ready for the next check run.

  > In any case, the `init/1` function is optional, and the `check/1` function
  can return either a simple `Result` or a `{Result, state}` tuple. Just take care
  you know what's going on with your state!

  ## Timeouts

  Note that checks must complete within the timeout period (`timeout_ms`) configured for
  the check (or globally in top-level config), or else they will be terminated (`:kill`ed)
  and will be set with a result of `:error`.
  """

  alias Fettle.Checker.Result

  @callback init(args :: any) :: any
  @callback check(state :: any) :: {Result.t(), state :: any} | Result.t()

  @optional_callbacks init: 1

  defmacro __using__(_opts) do
    quote do
      alias Fettle.Checker.Result

      @behaviour Fettle.Checker

      def init(state), do: state

      @defoverridable init: 1
    end
  end
end
