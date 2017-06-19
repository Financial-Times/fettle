defmodule Fettle.Runner do
  @moduledoc """
  Runs a health check periodically.

  The checks are spawned in a separate process, which is monitored for failure, and sends results
  back to the runner as a `Fettle.Checker.Result`.

  The first check is started after an initial delay (`:initial_delay_ms`), then checks are
  scheduled to run `:period_ms` after completion of the previous check..

  If a timeout occurs before a result is received, the check enters error status,
  and the checker process is killed.

  Results are forwarded to the `Fettle.ScoreBoard` process.
  """

  use GenServer

  require Logger

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

  @typedoc "check configuration"
  @type t :: %__MODULE__{
    id: String.t, # id of check
    fun: function, # function/0 to spawn to run test
    result: Checker.Result.t, # last result
    task: {pid, reference} | nil, # current executing test task
    period_ms: integer, # period of tests
    timeout_ms: integer, # timeout of tests
    scoreboard: atom # mostly for testing
  }

  def start_link(config, spec, fun, opts) do
    Logger.debug(fn -> "#{__MODULE__} start_link #{inspect [config, spec, fun, opts]}" end)

    GenServer.start_link(__MODULE__, [config, spec, fun, opts])
  end

  def init(args = [config = %Fettle.Config{}, spec = %Spec{}, fun, opts]) when is_function(fun, 0) and is_list(opts) do
    Logger.debug(fn -> "#{__MODULE__} init #{inspect args}" end)
    initial_delay_ms = opts[:initial_delay_ms] || config.initial_delay_ms || raise ArgumentError, "Need initial_delay_ms"
    period_ms = opts[:period_ms] || config.period_ms || raise ArgumentError, "Need period_ms"
    timeout_ms = opts[:timeout_ms] || config.timeout_ms || raise ArgumentError, "Need timeout_ms"

    scoreboard = opts[:scoreboard] || Fettle.ScoreBoard
    if(not(is_atom(scoreboard)), do: (raise ArgumentError, "scoreboard should be module atom"))

    initial_result = Checker.Result.ok("Not run yet")

    schedule_check(initial_delay_ms)

    {:ok, %__MODULE__{id: spec.id, fun: fun, period_ms: period_ms, timeout_ms: timeout_ms, result: initial_result, scoreboard: scoreboard}}
  end

  def handle_info({:result, result}, state = %__MODULE__{}) do
    # receive result from healthcheck:
    # store and forward to ScoreBoard
    Logger.debug(fn -> "Healthcheck #{state.id} result is #{String.upcase(Atom.to_string(result.status))}: #{result.message}" end)
    :ok = (state.scoreboard).result(state.id, result)
    {:noreply, %{state | result: result}}
  end

  def handle_info(:scheduled_check, state = %__MODULE__{id: id, fun: fun}) do
    # run healthcheck and schedule timeout
    runner = self()
    task = spawn_monitor(fn ->
      Logger.debug(fn -> "Running healthcheck #{id}" end)
      result = fun.()
      send(runner, {:result, result})
    end)

    {:noreply, %{state | task: task}, state.timeout_ms}
  end

  @doc "Handle timeout before we receive a health message"
  def handle_info(:timeout, state = %__MODULE__{task: {pid, _ref}}) do
    # check has timed out
    Logger.info(fn -> "Healthcheck #{state.id} timed out" end)

    Process.exit(pid, :kill)

    timeout_result = Checker.Result.error("Timeout")

    {:noreply, %{state | task: nil, result: timeout_result}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    # sub-process exited normally: reschedule
    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :killed}, state) do
    # sub-process was killed, hopefully by us: reschedule
    Logger.debug(fn -> "Healthcheck #{state.id} was killed" end)
    schedule_check(state.period_ms)

    {:noreply, %{state | task: nil}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # sub-process died, reschedule check
    Logger.warn(fn -> "Checker process for #{state.id} died: #{inspect reason}" end)

    schedule_check(state.period_ms)

    {:noreply, %{state | result: Checker.Result.error(inspect reason)}}
  end

  def schedule_check(ms) do
    Process.send_after(self(), :scheduled_check, ms)
  end
end
