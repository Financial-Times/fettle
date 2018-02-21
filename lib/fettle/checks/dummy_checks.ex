defmodule Fettle.AlwaysHealthyCheck do
  @moduledoc "A dummy check that is always healthy"

  use Fettle.Checker

  def check(_) do
    Result.ok()
  end
end

defmodule Fettle.NeverHealthyCheck do
  @moduledoc "A dummy check that is never healthy."

  use Fettle.Checker

  def check(_) do
    Result.error("Check failed")
  end
end
