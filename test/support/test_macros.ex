defmodule Fettle.TestMacros do
  defmacro testschema(name) do
    quote do
      defmodule unquote(name) do
        @behaviour Fettle.Schema

        defstruct [:systemCode, :count]

        def to_schema(app, checks) do
          %__MODULE__{systemCode: app.system_code, count: length(checks)}
        end
      end
    end
  end
end
