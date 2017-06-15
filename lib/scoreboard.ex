defmodule Fettle.ScoreBoard do
  @moduledoc """
  Keeps track of the results of health checks, as reported to it,
  and makes them available in a the configured schema format.

  The scoreboard requires that healthchecks are first registered with the process
  before it receives results; this is normally taken care of by the start-up
  configuration process and the run-time API.
  """

  use GenServer

  alias Fettle.Spec
  alias Fettle.Checker
  alias Fettle.Checker.Result
  alias Fettle.Schema

  @type config :: Fettle.Config.t
  @type check :: {Spec.t, Checker.Result.t}
  @type checks :: %{required(String.t) => check}
  @type state :: {config, checks}

  @doc "Produces a health report in the configured schema format."
  @spec report() :: Schema.Report.t
  def report() do
    GenServer.call(via(), :report)
  end

  @doc "Report a new health check result."
  @spec result(id :: String.t, Checker.Result.t) :: :ok
  def result(id, result = %Checker.Result{}) do
    GenServer.cast(via(), {:result, id, result})
  end

  @doc "Configure a new health check on the score board."
  @spec new(spec :: Spec.t) :: {:ok, id :: String.t}
  def new(spec = %Spec{}) do
    GenServer.call(via(), {:new, spec})
  end

  defp via do
    # register/lookup proc via the Registry
    {:via, Registry, {Fettle.Registry, __MODULE__}}
  end

  @doc "Start the scoreboard with a list of the checks it will keep results for."
  @spec start_link(config :: config, checks :: [{Spec.t, atom, any}]) :: GenServer.on_start
  def start_link(config, checks) do
    GenServer.start_link(__MODULE__, [config, checks], name: via())
  end

  @doc false
  @spec init(args :: [config | [{Spec.t, atom, any}]]) :: {:ok, state}
  def init([config, checks]) do
    timestamp = Fettle.TimeStamp.instant()

    # only interested in health check spec here
    checks = Enum.reduce(checks, Map.new(), fn
      ({spec, _module, _opts}, map) ->
        Map.put(map, spec.id, {spec, Result.new(:ok, "Not run yet", timestamp)})
    end)

    {:ok, {config, checks}}
  end

  @doc false
  @spec handle_cast({:result, id :: String.t, result :: Result.t}, state :: state) :: {:noreply, state}
  def handle_cast({:result, id, result = %Result{}}, _state = {config = %Fettle.Config{}, checks}) do
    # update healthcheck state

    checks = Map.update!(checks, id, fn
      {spec, _prev_result} -> {spec, result}
    end)

    {:noreply, {config, checks}}
  end

  @doc false
  @spec handle_call({:new, Spec.t}, pid, state) :: {:reply, {:ok, String.t}, state}
  def handle_call({:new, spec = %Spec{id: id}}, _pid, {app, checks}) do
    checks = put_in(checks[id], {spec, Checker.Result.new(:ok, "Not run yet")})

    {:reply, {:ok, spec.id}, {app, checks}}
  end

  @doc false
  @spec handle_call(:report, pid, state) :: {:reply, Schema.Report.t, state}
  def handle_call(:report, _pid, state = {app, checks}) do
    report_mod = app.schema || Fettle.Schema.FTHealthCheckV1
    report = report_mod.to_schema(app, Map.values(checks))
    {:reply, report, state}
  end

end