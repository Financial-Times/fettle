defmodule TestUtil do
  use ExUnit.Case

  def foo(_a, _b), do: 2

  test "compliant module complies" do
    assert __MODULE__ == Fettle.Util.check_module_complies(__MODULE__, __MODULE__, {:foo, 2})
  end

  test "compliant module complies!" do
    assert __MODULE__ == Fettle.Util.check_module_complies!(__MODULE__, __MODULE__, {:foo, 2})
  end

  test "non-compliant module does not comply" do
    assert {:error, _msg} = Fettle.Util.check_module_complies(__MODULE__, __MODULE__, {:foo, 1})
  end

  test "non-compliant module does not comply!" do
    assert_raise ArgumentError, fn ->
      Fettle.Util.check_module_complies!(__MODULE__, __MODULE__, {:foo, 1})
    end
  end

  test "non-extant module does not comply" do
    assert {:error, _msg} =
             Fettle.Util.check_module_complies(__MODULE__.Bar, __MODULE__, {:foo, 2})
  end

  test "non-extant module does not comply!" do
    assert_raise ArgumentError, fn ->
      Fettle.Util.check_module_complies!(__MODULE__.Bar, __MODULE__, {:foo, 2})
    end
  end
end
