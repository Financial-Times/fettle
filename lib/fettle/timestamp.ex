defmodule Fettle.TimeStamp do
  @moduledoc "Helper functions for creating and converting timestamps."

  @type t :: {timestamp :: integer, offset :: integer}

  @doc "Get a timestamp in monotonic time"
  @spec instant() :: t
  def instant do
    {System.monotonic_time(), System.time_offset()}
  end

  @doc "Add increment to instant; for tests"
  @spec incr(instant :: t, increment :: integer) :: t
  def incr(instant, increment)

  def incr({ts, offset}, increment) do
    {ts + increment, offset}
  end

  @doc "Convert an instant to a `DateTime`"
  @spec to_date_time(instant :: t) :: DateTime.t()
  def to_date_time(instant)

  def to_date_time({ts, offset}) do
    unix = ts + offset
    {:ok, date_time} = DateTime.from_unix(unix, :native)
    date_time
  end

  @doc "Convert an instant to an ISO-8601 dateTime string"
  @spec to_string(instant :: t) :: String.t()
  def to_string(instant)

  def to_string(instant = {_ts, _offset}) do
    dt = to_date_time(instant)
    DateTime.to_iso8601(dt)
  end
end
