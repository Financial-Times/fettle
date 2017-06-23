defmodule RunnerSuperTest do

  use ExUnit.Case

  alias Fettle.Spec

  setup do
    Application.ensure_all_started(:fettle)
    :ok
  end

  defmodule TestScoreBoard do
    def result(_id, _result) do
      :ok
    end
  end

  defmodule TestChecker do
    @behaviour Fettle.Checker

    def check(args) do
      parent = args[:parent]
      send(parent, :check_got_args)
      Fettle.Checker.Result.ok()
    end
  end

  test "ensure checker function is supplied with given args" do
    check = {
      %Spec{
        initial_delay_ms: 0,
        period_ms: 30_000,
        timeout_ms: 5_000
      },
      TestChecker,
      parent: self()
    }

    {:ok, _pid} = Fettle.RunnerSupervisor.start_check(check, scoreboard: TestScoreBoard)

    assert_receive :check_got_args
  end

end