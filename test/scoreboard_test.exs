defmodule ScoreBoardTest do
  use ExUnit.Case

  alias Fettle.ScoreBoard
  alias Fettle.Spec
  alias Fettle.Checker.Result
  alias Fettle.TimeStamp

  defmodule TestSchema do
    @behaviour Fettle.Schema.Api

    def to_schema(app, checks) do
      %{systemCode: app.system_code, count: length(checks)}
    end
  end


  test "init with no checks" do
    {:ok, state} = ScoreBoard.init([config(), []])

    assert state == {config(), %{}}
  end

  test "init with check puts check in state" do
    spec = %Fettle.Spec{
      id: "id",
      name: "foo"
    }
    id = spec.id

    check = {
      spec,
      MyModule,
      []
    }
    {:ok, {_app, checks}} = ScoreBoard.init([config(), [check]])

    assert checks[id]
    {^spec,  %Fettle.Checker.Result{}} = checks[id]
  end

  test "new check adds to state" do
    check1 = make_check("check-1")
    {:ok, state} = ScoreBoard.init([config(), [check1]])

    assert {_app, %{"check-1" => _}} = state

    spec = %Fettle.Spec{id: "check-2", name: "foo"}
    id = spec.id

    {:reply, {:ok, ^id}, {app, checks}} = ScoreBoard.handle_call({:new, spec}, nil, state)

    assert is_map(app)
    assert is_map(checks)
    assert checks[id]
    assert {^spec, result = %Fettle.Checker.Result{}} = checks[id]
    assert result.status == :ok
    assert result.message == "Not run yet"
  end

  test "updates state when receives results" do
    check1 = make_check("check-1")
    check2 = make_check("check-2")
    {:ok, state} = ScoreBoard.init([config(), [check1, check2]])

    {:noreply, state} = ScoreBoard.handle_cast({:result, "check-1", Result.new(:ok, "OK", 1)}, state)
    {:noreply, state} = ScoreBoard.handle_cast({:result, "check-2", Result.new(:warn, "Warn", 2)}, state)
    {:noreply, state} = ScoreBoard.handle_cast({:result, "check-1", Result.new(:error, "Error", 3)}, state)

    {_app, checks} = state

    assert {%Spec{id: "check-1"}, %Result{status: :error, message: "Error", timestamp: 3}} == checks["check-1"]
    assert {%Spec{id: "check-2"}, %Result{status: :warn, message: "Warn", timestamp: 2}} == checks["check-2"]
  end

  test "generates expected report" do
    check1 = make_check("check-1")
    check2 = make_check("check-2")
    {:ok, state} = ScoreBoard.init([config(), [check1, check2]])

    {:noreply, state} = ScoreBoard.handle_cast({:result, "check-1", %Result{status: :ok, message: "OK", timestamp: TimeStamp.instant()}}, state)
    {:noreply, state} = ScoreBoard.handle_cast({:result, "check-2", %Result{status: :error, message: "Error", timestamp: TimeStamp.incr(TimeStamp.instant(), 1000)}}, state)

    {:reply, report, ^state} = ScoreBoard.handle_call(:report, self(), state)

    assert %{systemCode: "test-app", count: 2} = report
  end

  defp make_check(id) do
    {
      %Fettle.Spec{
        id: id
      },
      MyModule,
      []
    }
  end

  defp config do
    %Fettle.Config{
      system_code: "test-app",
      schema: ScoreBoardTest.TestSchema
    }
  end

end