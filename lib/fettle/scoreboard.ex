defmodule Fettle.ScoreBoard do
  @moduledoc """
  Keeps track of the results of health checks, as reported to it,
  and makes them available in a the configured schema format.

  The scoreboard requires that healthchecks are first registered with the process
  before it receives results; this is normally taken care of by the start-up
  configuration process and the run-time API.
  """

  use GenServer

  alias Fettle.Config
  alias Fettle.Spec
  alias Fettle.Checker
  alias Fettle.Checker.Result
  alias Fettle.Schema

  @default_schema Fettle.Schema.FTHealthCheckV1

  @type check :: {Spec.t, Checker.Result.t}
  @type checks :: %{required(String.t) => check} # spec.id => check
  @type state :: {Config.t, checks}

  @doc "Produces a health report in a desired schema format."
  @spec report(schema :: atom) :: Schema.report
  def report(schema \\ nil) do
    GenServer.call(via(), {:report, schema})
  end

  @doc "Check if all tests are in a healthy (`:ok`) state."
  @spec ok?() :: boolean
  def ok?() do
    GenServer.call(via(), :ok?)
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

  @doc "Return the number of checks currently configured."
  def count_checks do
    GenServer.call(via(), :count)
  end

  defp via do
    # register/lookup proc via the Registry
    {:via, Registry, {Fettle.Registry, __MODULE__}}
  end

  @doc "Start the scoreboard with a list of the checks it will keep results for."
  @spec start_link(config :: Config.t, checks :: [Config.spec_and_mod]) :: GenServer.on_start
  def start_link(config = %Config{}, checks) when is_list(checks) do
    GenServer.start_link(__MODULE__, [config, checks], name: via())
  end

  @doc false
  @spec init(args :: [config :: Config.t | [Config.spec_and_mod]]) :: {:ok, state}
  def init([config = %Config{}, checks]) when is_list(checks) do
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
  def handle_cast({:result, id, result = %Result{}}, _state = {config = %Config{}, checks}) do
    # update healthcheck state

    checks = Map.update!(checks, id, fn
      {spec, _prev_result} -> {spec, result}
    end)

    {:noreply, {config, checks}}
  end

  @doc false
  @spec handle_call({:new, Spec.t}, GenServer.from, state) :: {:reply, {:ok, String.t}, state}
  def handle_call({:new, spec = %Spec{id: id}}, _pid, {app, checks}) do
    checks = put_in(checks[id], {spec, Checker.Result.new(:ok, "Not run yet")})

    {:reply, {:ok, spec.id}, {app, checks}}
  end

  @doc false
  @spec handle_call({:report, atom}, pid, state) :: {:reply, Schema.report, state}
  def handle_call({:report, schema}, _pid, state = {app, checks}) do
    report_mod = schema || app.schema || @default_schema
    report = report_mod.to_schema(app, Map.values(checks))
    {:reply, report, state}
  end

  @doc false
  def handle_call(:count, _pid, state = {_app, checks}) do
    {:reply, length(Map.keys(checks)), state}
  end

  @doc false
  def handle_call(:ok?, _pid, state = {_app, checks}) do
    ok? =
      checks
      |> Map.values
      |> Enum.all?(fn {_spec, result} -> result.status == :ok end)

    {:reply, ok?, state}
  end

end