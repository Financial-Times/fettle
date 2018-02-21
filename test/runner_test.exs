defmodule RunnerTest do
  use ExUnit.Case

  alias Fettle.Runner
  alias Fettle.Checker.Result
  alias Fettle.Spec

  defmodule TestScoreBoard do
    def result(id, result = %Result{}) do
      send(self(), {:test_scoreboard, id, result})
      :ok
    end
  end

  defmodule HealthyCheck do
    @behaviour Fettle.Checker

    def check(_) do
      Result.ok()
    end
  end

  test "init runner schedules first check" do
    spec = spec()

    {:ok, state} = Runner.init([config(), spec, {HealthyCheck, [:init]}, opts()])

    assert %Runner{
             id: "test-1",
             result: %Result{status: :ok},
             checker_state: [:init],
             checker_fun: fun
           } = state

    assert is_function(fun, 1)
    assert state.period_ms == spec.period_ms
    assert state.timeout_ms == spec.timeout_ms

    assert_receive :scheduled_check

    assert mailbox() == [], "Expected empty mailbox"
  end

  test "init runner with no_schedule does not schedule first check (test facility)" do
    spec = %{spec() | period_ms: 0}

    {:ok, _state} = Runner.init([config(), spec, {HealthyCheck, [:init]}, no_schedule_opts()])

    refute_receive :scheduled_check

    assert [] == mailbox()
  end

  test "scheduling message runs test" do
    {:ok, state} = Runner.init([config(), spec(), {HealthyCheck, [:init]}, no_schedule_opts()])

    {:noreply, Runner.handle_info(:scheduled_check, state)}

    assert_receive {:result, result, check_state}

    assert %{result | timestamp: nil} == %{Result.ok() | timestamp: nil}
    assert [:init] == check_state

    assert_receive {:DOWN, _ref, :process, _pid, :normal}

    assert [] == mailbox()
  end

  test "receive result: updates state and reports to scoreboard" do
    {:ok, state} = Runner.init([config(), spec(), {HealthyCheck, []}, no_schedule_opts()])

    result = Result.new(:warn, "Warning", 100)

    {:noreply, state} = Runner.handle_info({:result, result, [:checker_state]}, state)

    assert state.result == result
    assert state.checker_state == [:checker_state]

    assert_receive {:test_scoreboard, id, sb_result}

    assert id == state.id
    assert sb_result == result

    assert [] == mailbox()
  end

  test "timeout kills check, reports error to scoreboard, and re-schedules via DOWN" do
    defmodule TimeoutCheck do
      def check(_) do
        Process.sleep(10_000)
        Result.ok()
      end
    end

    # arrange immediate schedule on check
    spec = %{spec() | period_ms: 0}

    {:ok, state} = Runner.init([config(), spec, {TimeoutCheck, []}, no_schedule_opts()])

    {:noreply, state = %{task: {pid, ref}}, timeout} = Runner.handle_info(:scheduled_check, state)
    assert timeout == 5000

    # simulate timeout
    {:noreply, state} = Runner.handle_info(:timeout, state)

    expected_result = %Result{status: :error, message: "Timeout"}
    assert expected_result == %{state.result | timestamp: nil}

    assert_receive {:test_scoreboard, id, sb_result}

    assert id == state.id
    assert sb_result == state.result

    refute_receive :scheduled_check

    assert_receive down_message = {:DOWN, ^ref, :process, ^pid, :killed}

    {:noreply, state} = Runner.handle_info(down_message, state)
    assert state.task == nil

    assert_receive :scheduled_check

    assert [] == mailbox()
  end

  test "reschedules check when scheduled check exits normally" do
    spec = %{spec() | period_ms: 0}

    {:ok, state} =
      Runner.init([config(), spec, {HealthyCheck, [:checker_state]}, no_schedule_opts()])

    task = {self(), make_ref()}

    state = %{state | task: task}

    down_message = {:DOWN, elem(task, 1), :process, elem(task, 0), :normal}

    {:noreply, state} = Runner.handle_info(down_message, state)

    assert state.task == nil

    assert_receive :scheduled_check

    assert [] == mailbox()
  end

  test "reschedules check when scheduled check killed" do
    spec = %{spec() | period_ms: 0}

    {:ok, state} =
      Runner.init([config(), spec, {HealthyCheck, [:checker_state]}, no_schedule_opts()])

    down_message = {:DOWN, make_ref(), :process, self(), :killed}

    Runner.handle_info(down_message, state)
    assert_receive :scheduled_check

    assert [] == mailbox()
  end

  test "reschedules check when scheduled check exits abnormally" do
    defmodule BadExitCheck do
      def check(_) do
        exit(:sad!)
      end
    end

    spec = %{spec() | period_ms: 0}

    {:ok, state} = Runner.init([config(), spec, {BadExitCheck, []}, no_schedule_opts()])

    {:noreply, %{task: {pid, ref}}, _timeout} = Runner.handle_info(:scheduled_check, state)

    refute_receive {:result, _result, _checker_state}

    assert_receive down_message = {:DOWN, ^ref, :process, ^pid, :sad!}

    {:noreply, state} = Runner.handle_info(down_message, state)

    assert state.task == nil

    expected_result = %Result{status: :error, message: "Check died: :sad!"}

    assert expected_result == %{state.result | timestamp: nil}

    assert_receive {:test_scoreboard, _id, sb_result}

    assert sb_result == state.result

    assert_receive :scheduled_check, 100

    assert [] == mailbox()
  end

  test "maintains initial args for stateless checker without init/1" do
    defmodule StatelessCheck do
      def check(_) do
        Result.ok()
      end
    end

    {:ok, state} = Runner.init([config(), spec(), {StatelessCheck, [a: 1]}, opts()])

    assert state.checker_state == [a: 1]

    assert_receive :scheduled_check

    {:noreply, state, _timeout} = Runner.handle_info(:scheduled_check, state)

    assert state.checker_state == [a: 1]

    assert_receive {:result, _, [a: 1]}

    mailbox()
  end

  test "maintains initial state for stateless checker with init/1" do
    defmodule InitStatelessCheck do
      def init(args) do
        Enum.into(args, %{b: 2})
      end

      def check(%{a: 1, b: 2}) do
        Result.ok()
      end
    end

    {:ok, state} = Runner.init([config(), spec(), {InitStatelessCheck, [a: 1]}, opts()])

    assert state.checker_state == %{a: 1, b: 2}

    assert_receive :scheduled_check

    {:noreply, state, _timeout} = Runner.handle_info(:scheduled_check, state)

    assert state.checker_state == %{a: 1, b: 2}

    assert_receive {:result, _, %{a: 1, b: 2}}

    mailbox()
  end

  test "maintains checker state for stateful checker with init/1" do
    defmodule InitStatefulCheck do
      def init(%{x: x}) do
        x + 1
      end

      def check(x) do
        {Result.ok(), x + 1}
      end
    end

    {:ok, state} = Runner.init([config(), spec(), {InitStatefulCheck, %{x: 10}}, opts()])

    assert state.checker_state == 11

    assert_receive :scheduled_check

    {:noreply, state, _timeout} = Runner.handle_info(:scheduled_check, state)

    assert_receive result = {:result, _, 12}

    {:noreply, state} = Runner.handle_info(result, state)

    {:noreply, state, _timeout} = Runner.handle_info(:scheduled_check, state)

    assert_receive result = {:result, _, 13}

    {:noreply, state} = Runner.handle_info(result, state)

    assert state.checker_state == 13

    mailbox()
  end

  test "maintains checker state for stateful checker without init/1" do
    defmodule SimpleStatefulCheck do
      def check(args = %{x: x}) do
        {Result.ok(), %{args | x: x + 1}}
      end
    end

    {:ok, state} = Runner.init([config(), spec(), {SimpleStatefulCheck, %{x: 10, y: 1}}, opts()])

    assert state.checker_state == %{x: 10, y: 1}

    assert_receive :scheduled_check

    {:noreply, state, _timeout} = Runner.handle_info(:scheduled_check, state)

    assert_receive result = {:result, _, %{x: 11, y: 1}}

    {:noreply, state} = Runner.handle_info(result, state)

    {:noreply, state, _timeout} = Runner.handle_info(:scheduled_check, state)

    assert_receive result = {:result, _, %{x: 12, y: 1}}

    {:noreply, state} = Runner.handle_info(result, state)

    assert state.checker_state == %{x: 12, y: 1}

    mailbox()
  end

  defp mailbox(mailbox \\ []) do
    receive do
      message ->
        mailbox([message | mailbox])
    after
      0 ->
        mailbox
    end
  end

  defp opts, do: [scoreboard: TestScoreBoard]

  defp no_schedule_opts, do: [{:no_schedule, true} | opts()]

  defp spec do
    %Spec{
      id: "test-1",
      name: "name-of-test-1",
      initial_delay_ms: 0,
      period_ms: 30_000,
      timeout_ms: 5000
    }
  end

  defp config do
    %Fettle.Config{
      initial_delay_ms: 0,
      period_ms: 10_000,
      timeout_ms: 1000
    }
  end
end
