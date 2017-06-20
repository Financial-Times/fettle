defmodule Fettle.Checker.Result do
  @moduledoc "Result struct which is returned from `Fettle.Checker` functions."

  defstruct [:status, :message, :timestamp]

  alias Fettle.TimeStamp

  @type status :: :ok | :warn | :error
  @type message :: String.t
  @type t :: %__MODULE__{status: status, message: message, timestamp: TimeStamp.t}

  @doc "create a new result with the current timestamp"
  def new(status, message), do: new(status, message, TimeStamp.instant())

  @doc "create a new result with the supplied timestamp"
  def new(status, message, timestamp) when status in [:ok, :warn, :error] do
    %__MODULE__{
      status: status,
      message: message,
      timestamp: timestamp
    }
  end

  @doc "error result shortcut."
  def error(message), do: new(:error, message)

  @doc "warn result shortcut."
  def warn(message), do: new(:warn, message)

  @doc "ok result shortcut."
  def ok(message \\ "OK"), do: new(:ok, message)

end
