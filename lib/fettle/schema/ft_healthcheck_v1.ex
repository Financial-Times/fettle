defmodule Fettle.Schema.FTHealthCheckV1 do
  @moduledoc """
  Implements the [FT Health Check Schema V1](../../../FTHealthcheckstandard.pdf).

  JSON serialized output is of form:
  ```json
  {
    "schemaVersion": 1,
    "systemCode": "code",
    "name": "name of system",
    "decription": "description of system",
    "checks": [
      {
        "id": "healthcheck-id-1",
        "name": "healthcheck name",
        "ok": false,
        "severity": 1,
        "businessImpact": "description",
        "technicalSummary": "description",
        "panicGuide": "https://...",
        "checkOutput": "message from check",
        "lastUpdated": "2017-06-23T09:13:24Z"
      }
    ]
  }
  ```
  Most fields fairly obviously map to config, however:

  * `checkOutput` is the `Fettle.Checker.Result.message` field.
  * `ok` is `false` if the `Fettle.Checker.Result.status` is not `:ok`.
  * `lastUpdated` is the `Fettle.Checker.Result.timestamp` field as ISO-8601 UTC DateTime.

  Note that the `:warn` and `:error` states are not exposed by this standard other than
  as the computed value of `ok`; the FT instead uses the (non-dynamic) `severity` to show
  different levels of alert on dash-boards, with the intention of using multiple checks for
  to distinguish between errors and warnings.

  """

  @behaviour Fettle.Schema

  @schema_version 1

  defmodule CheckResult do
    @moduledoc "A single FT Healthcheck V1 check result"

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
  alias Fettle.ScoreBoard

  @spec to_schema(config :: Fettle.Config.t, results :: [ScoreBoard.check]) :: Fettle.Schema.report
  def to_schema(config, results) when is_map(config) and is_list(results) do
    %__MODULE__.Report{
      schemaVersion: @schema_version,
      systemCode: config.system_code,
      name: config.name || config.system_code,
      description: config.description || config.system_code,
      checks: results_to_schema(results)
    }
  end

  @doc false
  @spec results_to_schema([ScoreBoard.check]) :: [CheckResult.t]
  def results_to_schema(results) when is_list(results) do
    Enum.map(results, &result_to_schema/1)
  end

  @doc false
  @spec result_to_schema(ScoreBoard.check) :: CheckResult.t
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
