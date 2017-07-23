defmodule Fettle.RunnerSupervisor do
  @moduledoc """
  Starts and supervises `Fettle.Runner` processes.

  `start_link/2` starts the supervisor which creates `Fettle.Runner` processes for a
  list of checks, potentially from config, linking the current process to the supervisor.

  `start_check/2` is subsequently used for dynamically adding new checks; it takes a tuple
  `{%Spec{}, CheckerModule, args}` to define the check, and an optional keyword list
  (which is principally for debugging).

  Clients will normally prefer `Fettle.add/3` to dynamically add checks.
  """

  use Supervisor

  require Logger

  alias Fettle.Config
  alias Fettle.Spec

  @doc false
  @spec start_link(config :: Config.t, checks :: [Config.spec_and_mod]) :: Supervisor.on_start
  def start_link(config = %Config{}, checks) when is_list(checks) do
    Logger.debug(fn -> "#{__MODULE__} start_link #{inspect [config, checks]}" end)
    Supervisor.start_link(__MODULE__, [config, checks], name: via())
  end

  @doc false
  def init([config = %Config{}, checks]) when is_list(checks) do
    Logger.debug(fn -> "#{__MODULE__} init #{inspect [config, checks]}" end)

    children = [
      worker(Fettle.Runner, [config]) # supply config as first argument for Fettle.Runner workers
    ]

    _pid = spawn_link(fn -> start_checks(checks) end)

    supervise(children, strategy: :simple_one_for_one)
  end

  @doc "Start running a list of checks."
  @spec start_checks([Config.spec_and_mod]) :: :ok
  def start_checks(checks) when is_list(checks) do
    Enum.each(checks, fn
      check -> {:ok, _pid} = start_check(check)
    end)
  end

  @doc """
  Start running a check periodically.

  ### Options
  `scoreboard` - module providing `Fettle.ScoreBoard.result/2` compatible function (for testing).
  """
  @spec start_check(check :: Config.spec_and_mod) :: Supervisor.on_start_child
  def start_check(check, opts \\ [])

  def start_check({spec = %Spec{}, module, init_args}, opts) when is_atom(module) do
    Logger.debug(fn -> "#{__MODULE__} start_check #{inspect spec}" end)

    {:ok, _pid} = Supervisor.start_child(via(), [spec, {module, init_args}, opts])
  end

  @doc "Return the number of checks currently configured."
  def count_checks do
    Supervisor.count_children(via()).workers
  end

  defp via do
    # register/lookup proc via the Registry
    {:via, Registry, {Fettle.Registry, __MODULE__}}
  end

end