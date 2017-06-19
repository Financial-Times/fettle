defmodule FettleTest do
  use ExUnit.Case

  import Fettle.TestMacros

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