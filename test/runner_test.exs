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


  test "init runner schedules first check" do

    fun = fn -> Result.new(:ok, "OK") end
    opts = [
      initial_delay_ms: 0,
      period_ms: 1000,
      timeout_ms: 5000,
      scoreboard: TestScoreBoard
    ]

    {:ok, state} = Runner.init([config(), spec(), fun, opts])

    assert %Runner{id: "test-1", fun: ^fun, result: %Result{status: :ok}, period_ms: 1000, timeout_ms: 5000} = state

    assert_receive :scheduled_check

    assert mailbox() == [], "Expected empty mailbox"
  end

  test "receive result: updates state and sends to scoreboard" do
    fun = fn -> Result.new(:ok, "OK") end
    opts = [
      initial_delay_ms: 0,
      period_ms: 0,
      timeout_ms: 5000,
      scoreboard: TestScoreBoard
    ]
    {:ok, state} = Runner.init([config(), spec(), fun, opts])

    assert_receive :scheduled_check

    result = Result.new(:warn, "Warning", 100)

    {:noreply, state} = Runner.handle_info({:result, result}, state)

    assert state.result == result

    assert_receive {:test_scoreboard, id, sb_result}

    assert id == state.id
    assert sb_result == result

    assert mailbox() == [], "Expected empty mailbox"
  end

  test "timeout kills check and reschedules" do
    fun = fn -> Process.sleep(10000) end
    opts = [
      initial_delay_ms: 0,
      period_ms: 0,
      timeout_ms: 5000,
      scoreboard: TestScoreBoard
    ]
    {:ok, state} = Runner.init([config(), spec(), fun, opts])

    assert_receive :scheduled_check

    {:noreply, state = %{task: {pid, ref}}, timeout} = Runner.handle_info(:scheduled_check, state)

    assert timeout == 5000

    {:noreply, state_timeout} = Runner.handle_info(:timeout, state)

    assert %Result{status: :error, message: "Timeout"} = state_timeout.result
    assert state_timeout.task == nil

    assert_receive down_message = {:DOWN, ^ref, :process, ^pid, :killed}

    {:noreply, state} = Runner.handle_info(down_message, state)

    assert state.task == nil

    assert_receive :scheduled_check

    assert mailbox() == [], "Expected empty mailbox"
  end

  test "reschedules check when scheduled check exits normally" do
    fun = fn -> Result.ok() end
    opts = [
      initial_delay_ms: 0,
      period_ms: 0,
      timeout_ms: 5000,
      scoreboard: TestScoreBoard
    ]
    {:ok, state} = Runner.init([config(), spec(), fun, opts])

    assert_receive :scheduled_check

    {:noreply, %{task: {pid, ref}}, timeout} = Runner.handle_info(:scheduled_check, state)

    assert timeout == 5000

    assert_receive {:result, %Result{status: :ok}}
    assert_receive down_message = {:DOWN, ^ref, :process, ^pid, :normal}

    {:noreply, state} = Runner.handle_info(down_message, state)

    assert state.task == nil

    assert_receive :scheduled_check

    assert mailbox() == [], "Expected empty mailbox"
  end

  test "reschedules check when scheduled check exits abnormally" do
    fun = fn -> exit(:sad!) end
    opts = [
      initial_delay_ms: 0,
      period_ms: 0,
      timeout_ms: 5000,
      scoreboard: TestScoreBoard
    ]
    {:ok, state} = Runner.init([config(), spec(), fun, opts])

    assert_receive :scheduled_check

    {:noreply, %{task: {pid, ref}}, timeout} = Runner.handle_info(:scheduled_check, state)

    assert timeout == 5000

    refute_receive {:result, _result}
    assert_receive down_message = {:DOWN, ^ref, :process, ^pid, :sad!}

    {:noreply, state} = Runner.handle_info(down_message, state)

    assert state.task == nil
    assert %Result{status: :error, message: ":sad!"} = state.result

    assert_receive :scheduled_check

    assert mailbox() == [], "Expected empty mailbox"
  end


  defp mailbox(mailbox \\ []) do
    receive do
      message ->
        mailbox([message | mailbox])
    after 0 ->
      mailbox
    end
  end

  defp spec do
    %Spec{
      id: "test-1",
      name: "name-of-test-1"
    }
  end

  defp config do
    %Fettle.Config{
      system_code: "test",
      panic_guide_url: "panic_guide_url"
    }
  end


end