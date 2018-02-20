defmodule Fettle.Runner do
  @moduledoc """
  Runs a health check periodically.

  The `start_link/4` function is called by the `Fettle.RunnerSupervisor` to start the server,
  passing the check spec, and `Checker` module to run.

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
    :checker_fun,
    :checker_state,
    :result,
    :task,
    :period_ms,
    :timeout_ms,
    :scoreboard
  ]

  @typedoc "runner state"
  @type t :: %__MODULE__{
    id: String.t, # id of check
    checker_fun: function, # function/1 to spawn to run test
    checker_state: any, # checker state chain across checks
    result: Checker.Result.t, # last result
    task: {pid, reference} | nil, # current executing test task
    period_ms: integer, # period of tests
    timeout_ms: integer, # timeout of tests
    scoreboard: atom # so we can set an alternate module for testing
  }

  @type checker_init :: {checker :: module, init_args :: any}

  @doc "start the runner for the given check."
  @spec start_link(config :: Config.t, spec :: Spec.t, checker_init :: checker_init, opts :: Keyword.t) :: GenServer.on_start
  def start_link(config = %Config{}, spec = %Spec{}, checker_init, opts) when is_list(opts) do
    Logger.debug(fn -> "#{__MODULE__} start_link #{inspect [spec, checker_init, opts]}" end)

    GenServer.start_link(__MODULE__, [config, spec, checker_init, opts])
  end

  @doc false
  def init(args = [config = %Config{}, spec = %Spec{}, {checker_mod, init_args}, opts]) when is_atom(checker_mod) and is_list(opts) do
    Logger.debug(fn -> "#{__MODULE__} init #{inspect args}" end)

    initial_delay_ms = spec.initial_delay_ms || config.initial_delay_ms || raise ArgumentError, "Need initial_delay_ms"
    period_ms = spec.period_ms || config.period_ms || raise ArgumentError, "Need period_ms"
    timeout_ms = spec.timeout_ms || config.timeout_ms || raise ArgumentError, "Need timeout_ms"

    scoreboard = opts[:scoreboard] || Fettle.ScoreBoard
    Fettle.Util.check_module_complies!(scoreboard, Fettle.ScoreBoard, {:result, 2})

    initial_result = Checker.Result.ok("Not run yet")

    if !opts[:no_schedule] do
      schedule_check(initial_delay_ms)
    end

    init_state = if(function_exported?(checker_mod, :init, 1), do: checker_mod.init(init_args), else: init_args)

    checker_fun = fn(state) -> checker_mod.check(state) end

    {:ok, %__MODULE__{id: spec.id, checker_fun: checker_fun, checker_state: init_state, period_ms: period_ms, timeout_ms: timeout_ms, result: initial_result, scoreboard: scoreboard}}
  end

  @doc "Runs healthcheck, and schedules timeout"
  def handle_info(:scheduled_check, state = %__MODULE__{id: id, checker_fun: checker_fun, checker_state: checker_state}) do

    runner = self()

    task = spawn_monitor(fn ->
      Logger.debug(fn -> "Running healthcheck #{id}" end)
      run_check(checker_fun, checker_state, runner)
    end)

    {:noreply, %{state | task: task}, state.timeout_ms}
  end

  @doc "Receives result from healthcheck, stores and forwards to `Fettle.ScoreBoard`"
  def handle_info({:result, result = %Checker.Result{}, checker_state}, state = %__MODULE__{}) do
    Logger.debug(fn -> "Healthcheck #{state.id} result is #{String.upcase(Atom.to_string(result.status))}: #{result.message}" end)

    report_result(state, result)

    {:noreply, %{state | result: result, checker_state: checker_state}}
  end

  @doc "Handles if a timeout occurs before we receive a result message"
  def handle_info(:timeout, state = %__MODULE__{task: {pid, _ref}}) do
    # check has timed out, report error; :DOWN handling will reschedule
    Logger.info(fn -> "Healthcheck #{state.id} timed out" end)

    Process.exit(pid, :kill)

    timeout_result = Checker.Result.error("Timeout")

    report_result(state, timeout_result)

    {:noreply, %{state | result: timeout_result}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    # sub-process exited normally: just reschedule
    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, :killed}, state) do
    # sub-process was killed, hopefully by us: just reschedule
    Logger.debug(fn -> "Healthcheck #{state.id} was killed" end)

    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # sub-process died, report error and reschedule check
    Logger.warn(fn -> "Checker process for #{state.id} died: #{inspect reason}" end)

    down_result = Checker.Result.error("Check died: #{inspect reason}")

    report_result(state, down_result)

    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil, result: down_result}}
  end

  defp report_result(%__MODULE__{id: id, scoreboard: scoreboard}, %Checker.Result{} = result) do
    :ok = scoreboard.result(id, result)
  end

  @doc false
  defp run_check(fun, state, result_receiver) do
      case fun.(state) do
        {result = %Checker.Result{}, new_state} ->
          send(result_receiver, {:result, result, new_state})
        result = %Checker.Result{} ->
          send(result_receiver, {:result, result, state})
      end
  end

  defp schedule_check(ms) do
    Process.send_after(self(), :scheduled_check, ms)
  end
end
