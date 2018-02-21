defmodule Fettle.Supervisor do
  @moduledoc """
  The `Fettle` supervisor starts two servers; `Fettle.ScoreBoard` a
  `GenServer` which responds to queries about the current health status,
  and `Fettle.RunnerSupervisor` a supervisor which starts worker `Fettle.Runner` servers
  running the health-checks themselves, and takes care of restarting them if they
  exit abnormally.

  The `RunnerSupervisor` starts a worker process for each configured
  `Health.Spec`, configuring them so they report results back to
  the `ScoreBoard` process.

  ### Supervision Tree

  - Fettle.Supervisor
    - Registry (`Fettle.Registry`)
    - Fettle.ScoreBoard
    - Fettle.RunnerSupervisor
      - Fettle.Runner

  ## Config

  By default Fettle loads configuration from the `:fettle` OTP application key;
  alternatively you can pass a `:config` option with either a `{M,F,A}`,
  a zero-args anonymous function, or some in-line configuration as a `Keyword` list:

  ```
  Fettle.Supervisor.start_link(config: {MyMod, :fettle, []}) # calls `MyMod.fettle/0`
  # or
  Fettle.Supervisor.start_link(config: [
    system_code: "app",
    name: "My Application",
    checks: [...]
  ]) # inline config
  ```

  See `Fettle.Config` for format details.

  > When using application configuration under the `:fettle` key, Fettle uses
  [DeferredConfig](https://hexdocs.pm/deferred_config) to resolve `{:system, "ENV_VAR"}` style
  tuples using shell enviroment variables; this works for all config values: values will
  be automatically cast to integers as required.
  """

  use Supervisor

  alias Fettle.Config

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, [])
  end

  def init(opts) do
    env = fetch_env(opts)

    app_config =
      env
      |> Keyword.drop([:checks])
      |> Enum.into(Map.new())
      |> Config.to_app_config()

    checks = env[:checks] || []
    checks = Enum.map(checks, fn check -> Config.check_from_config(check, app_config) end)

    # Define workers and child supervisors to be supervised
    children = [
      {Registry, [keys: :unique, name: Fettle.Registry]},
      {Fettle.ScoreBoard, [app_config, checks]},
      {Fettle.RunnerSupervisor, [app_config, checks]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp fetch_env(opts) do
    case opts[:config] do
      nil ->
        # old-school but convenient
        Application.get_all_env(:fettle)
        |> DeferredConfig.transform_cfg()

      {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, a)

      f when is_function(f, 0) ->
        f.()

      [{k, _v} | _] = config when is_list(config) and is_atom(k) ->
        config
    end
  end
end
