defmodule TimeTest do
  use ExUnit.Case

  alias Fettle.TimeStamp

  test "instant is monotonic & offset" do
    ts = {System.monotonic_time(), System.time_offset()}
    {instant, offset} = TimeStamp.instant()

    assert_in_delta elem(ts, 0), instant, 100_000
    assert_in_delta elem(ts, 1), offset, 100_000
  end

  test "instant to iso8601" do
    assert "2017-06-05T17:00:33.911586Z" ==
             TimeStamp.to_string({-576_460_708_744_679_591, 2_073_142_742_656_266_000})
  end
end
