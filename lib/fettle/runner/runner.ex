defmodule Fettle.Runner do
  @moduledoc """
  Runs a health check periodically.

  The `start_link/4` function is called by the `Fettle.RunnerSupervisor` to start the server,
  passing the config, check spec, zero-arity check function to run, and options from check
  configuration (minus the `:args` which are already part of the function).

  When a check is scheduled to run, the server spawns the check function in a separate, monitored process,
  which will send the result back to the runner as a `Fettle.Checker.Result`.

  The first check execution is scheduled after an initial delay (`:initial_delay_ms`), then the
  check is scheduled to run `:period_ms` after completion of the previous check. i.e. the period
  does not include the time it takes to actually run the check, just the time between completions
  (or time-outs); effectively the period defines the maximum rate that a check will run.

  If a timeout (`:timeout_ms`) occurs before a result is received, the check enters error status,
  and the spawned checker process is killed by the `Runner`.

  Results are forwarded to the `Fettle.ScoreBoard` process.

  ## See also
  * `Fettle.RunnerSupervisor` - starts and supervises `Runner` processes.

  """

  use GenServer

  require Logger

  alias Fettle.Config
  alias Fettle.Checker
  alias Fettle.Spec

  defstruct [
    :id,
    :fun,
    :result,
    :task,
    :period_ms,
    :timeout_ms,
    :scoreboard
  ]

  @typedoc "runner configuration"
  @type t :: %__MODULE__{
    id: String.t, # id of check
    fun: function, # function/0 to spawn to run test
    result: Checker.Result.t, # last result
    task: {pid, reference} | nil, # current executing test task
    period_ms: integer, # period of tests
    timeout_ms: integer, # timeout of tests
    scoreboard: atom # so we can set an alternate module for testing
  }

  @doc "start the runner for the given check."
  @spec start_link(config :: Config.t, spec :: Spec.t, fun :: (() -> Checker.Result.t), opts :: Keyword.t) :: GenServer.on_start
  def start_link(config = %Config{}, spec = %Spec{}, fun, opts) when is_function(fun, 0) and is_list(opts) do
    Logger.debug(fn -> "#{__MODULE__} start_link #{inspect [config, spec, fun, opts]}" end)

    GenServer.start_link(__MODULE__, [config, spec, fun, opts])
  end

  @doc false
  def init(args = [config = %Config{}, spec = %Spec{}, fun, opts]) when is_function(fun, 0) and is_list(opts) do
    Logger.debug(fn -> "#{__MODULE__} init #{inspect args}" end)

    initial_delay_ms = opts[:initial_delay_ms] || config.initial_delay_ms || raise ArgumentError, "Need initial_delay_ms"
    period_ms = opts[:period_ms] || config.period_ms || raise ArgumentError, "Need period_ms"
    timeout_ms = opts[:timeout_ms] || config.timeout_ms || raise ArgumentError, "Need timeout_ms"

    scoreboard = opts[:scoreboard] || Fettle.ScoreBoard
    Fettle.Util.check_module_complies!(scoreboard, Fettle.ScoreBoard, {:result, 2})

    initial_result = Checker.Result.ok("Not run yet")

    schedule_check(initial_delay_ms)

    {:ok, %__MODULE__{id: spec.id, fun: fun, period_ms: period_ms, timeout_ms: timeout_ms, result: initial_result, scoreboard: scoreboard}}
  end

  @doc "Receives result from healthcheck, stores and forwards to `Fettle.ScoreBoard`"
  def handle_info({:result, result = %Checker.Result{}}, state = %__MODULE__{}) do
    Logger.debug(fn -> "Healthcheck #{state.id} result is #{String.upcase(Atom.to_string(result.status))}: #{result.message}" end)

    :ok = (state.scoreboard).result(state.id, result)
    {:noreply, %{state | result: result}}
  end

  @doc "Runs healthcheck, and schedules timeout"
  def handle_info(:scheduled_check, state = %__MODULE__{id: id, fun: fun}) do
    runner = self()
    task = spawn_monitor(fn ->
      Logger.debug(fn -> "Running healthcheck #{id}" end)
      result = fun.()
      send(runner, {:result, result})
    end)

    {:noreply, %{state | task: task}, state.timeout_ms}
  end

  @doc "Handles if a timeout occurs before we receive a result message"
  def handle_info(:timeout, state = %__MODULE__{task: {pid, _ref}}) do
    # check has timed out
    Logger.info(fn -> "Healthcheck #{state.id} timed out" end)

    Process.exit(pid, :kill)

    timeout_result = Checker.Result.error("Timeout")

    {:noreply, %{state | task: nil, result: timeout_result}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    # sub-process exited normally: reschedule
    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :killed}, state) do
    # sub-process was killed, hopefully by us: reschedule
    Logger.debug(fn -> "Healthcheck #{state.id} was killed" end)
    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # sub-process died, reschedule check
    Logger.warn(fn -> "Checker process for #{state.id} died: #{inspect reason}" end)

    schedule_check(state.period_ms)

    {:noreply, %{state | result: Checker.Result.error(inspect reason)}}
  end

  defp schedule_check(ms) do
    Process.send_after(self(), :scheduled_check, ms)
  end
end
