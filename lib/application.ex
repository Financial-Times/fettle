defmodule Fettle.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc """
  The `Fettle` supervisor starts two servers; `Fettle.ScoreBoard` a
  `GenServer` which responds to queries about the current health status,
  and `Fettle.RunnerSupervisor` a supervisor which starts worker `Fettle.Runner` servers
  running the health-checks themselves, and takes care of restarting them if they
  exit abnormally.

  The `RunnerSupervisor` starts a worker process for each configured
  `Health.Spec`, configuring them so they report results back to
  the `ScoreBoard` process.

  - :fettle OTP app supervisor
    - Fettle.ScoreBoard
    - Fettle.RunnerSupervisor
      - Fettle.Runner
  """

  use Application

  alias Fettle.Config

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    env = Application.get_all_env(:fettle)
    app_config = Keyword.drop(env, [:checks]) |> Enum.into(Map.new) |> Config.to_app_config()
    checks = env[:checks] || []
    checks = Enum.map(checks, fn check -> Config.check_from_config(check, app_config) end)

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Registry, [:unique, Fettle.Registry]),
      worker(Fettle.ScoreBoard, [app_config, checks]),
      supervisor(Fettle.RunnerSupervisor, [app_config, checks])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

end
