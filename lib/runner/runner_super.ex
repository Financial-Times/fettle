defmodule Fettle.RunnerSupervisor do
  @moduledoc "Supervises `Fettle.Runner` processes."

  use Supervisor

  require Logger

  alias Fettle.Spec

  @doc false
  def start_link(config, checks) do
    Logger.debug(fn -> "#{__MODULE__} start_link #{inspect [config, checks]}" end)
    Supervisor.start_link(__MODULE__, [config, checks], name: via())
  end

  @doc false
  def init([config, checks]) do
    Logger.debug(fn -> "#{__MODULE__} init #{inspect [config, checks]}" end)

    children = [
      worker(Fettle.Runner, [config]) # supply config as first argument for Fettle.Runner workers
    ]

    _pid = spawn_link(fn -> start_checks(checks) end)

    supervise(children, strategy: :simple_one_for_one)
  end

  @doc "Start running a list of checks."
  def start_checks(checks) when is_list(checks) do
    Logger.debug(fn -> "#{__MODULE__} start_checks #{inspect checks}" end)
    Enum.each(checks, fn
      check -> start_check(check)
    end)
  end

  @doc "Start running a check periodically."
  @spec start_check({Spec.t, atom, Keyword.t}) :: :ok
  def start_check({spec = %Spec{}, module, opts}) when is_atom(module) do
    Logger.debug(fn -> "#{__MODULE__} start_check #{inspect spec}" end)
    runner_opts = Keyword.drop(opts, :args)

    check_fun_args = opts[:args] || [[]]
    check_fun = fn -> apply(module, :check, check_fun_args) end

    Supervisor.start_child(via(), [spec, check_fun, runner_opts])
  end

  defp via do
    # register/lookup proc via the Registry
    {:via, Registry, {Fettle.Registry, __MODULE__}}
  end

end