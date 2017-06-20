defmodule Fettle.Schema.FTHealthCheckV1 do
  @moduledoc """
  Implements the [FT Health Check Schema V1](../../../FTHealthcheckstandard.pdf).
  """

  @behaviour Fettle.Schema

  @schemaVersion 1

  defmodule CheckResult do
    @moduledoc "A single check result"

    defstruct [
      :id,
      :name,
      :ok,
      :lastUpdated,
      :checkOutput,
      :severity,
      :businessImpact,
      :technicalSummary,
      :panicGuide
    ]

    @type t :: %__MODULE__{
      id: String.t,
      name: String.t,
      ok: boolean,
      lastUpdated: String.t,
      checkOutput: String.t,
      severity: integer,
      businessImpact: String.t,
      technicalSummary: String.t,
      panicGuide: String.t
    }

  end

  defmodule Report do
    @moduledoc "The top-level FT Healthcheck V1 report."

    defstruct [
      :schemaVersion,
      :systemCode,
      :name,
      :description,
      :checks
    ]

    @type t :: %__MODULE__{
      schemaVersion: integer,
      systemCode: String.t,
      name: String.t,
      description: String.t,
      checks: [CheckResult.t]
    }
  end

  alias Fettle.TimeStamp
  alias Fettle.Spec

  @spec to_schema(config :: Fettle.Config.t, results :: [Api.check]) :: Report.t
  def to_schema(config, results) when is_map(config) and is_list(results) do
    %__MODULE__.Report{
      schemaVersion: @schemaVersion,
      systemCode: config.system_code,
      name: config.name || config.system_code,
      description: config.description || config.system_code,
      checks: results_to_schema(results)
    }
  end

  @spec results_to_schema([Api.check]) :: [CheckResult.t]
  def results_to_schema(results) when is_list(results) do
    Enum.map(results, &result_to_schema/1)
  end

  @spec result_to_schema(Api.check) :: CheckResult.t
  def result_to_schema({healthcheck = %Spec{}, %Fettle.Checker.Result{status: status, message: msg, timestamp: ts}}) do
    %CheckResult{
      id: healthcheck.id,
      name: healthcheck.name,
      ok: status == :ok,
      lastUpdated: TimeStamp.to_string(ts),
      checkOutput: msg,
      severity: healthcheck.severity,
      businessImpact: healthcheck.business_impact,
      technicalSummary: healthcheck.technical_summary,
      panicGuide: healthcheck.panic_guide_url
    }
  end
end
