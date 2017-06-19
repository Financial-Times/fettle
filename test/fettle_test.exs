defmodule FettleTest do
  use ExUnit.Case

  import Fettle.TestMacros

  describe "reports" do

    testschema TestSchema

    test "reports with custom schema" do
      assert %FettleTest.TestSchema{} = Fettle.report(TestSchema)
    end

    test "fails with invalid schema" do
      assert_raise ArgumentError, fn -> Fettle.report(NoSchema) end
    end

    test "reports with default schema" do
      assert Fettle.report()
    end

  end

  describe "add checks" do

    defmodule TestCheck do
      @behaviour Fettle.Checker

      def check(_args) do
        Fettle.Checker.Result.ok()
      end
    end

    test "adds check to both scoreboard and runner super" do
      no_of_checks = Fettle.RunnerSupervisor.count_checks()

      spec = %Fettle.Spec{id: "test-check", name: "test-check"}
      :ok = Fettle.add(spec, TestCheck, [])

      assert Fettle.ScoreBoard.count_checks() == no_of_checks + 1
      assert Fettle.RunnerSupervisor.count_checks() == no_of_checks + 1

      report = Fettle.ScoreBoard.report()
      assert Enum.find(report.checks, fn check -> check.name == "test-check" end)
    end
  end

end