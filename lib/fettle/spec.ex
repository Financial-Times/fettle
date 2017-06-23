defmodule Fettle.Spec do
  @moduledoc """
  Describes health-check meta-data, created from configuration and used
  to generate reports.

  All the fields must have values, but some can be provided from the
  global config, see `Fettle.Config`.

  | Field | Summary | Default |
  | ----- | ------- | ------- |
  | `id`  | Unique ID | defaults to value of `name` |
  | `name`  | Unique Name | Human readable name, required |
  | `description` | Description of what check does | defaults to value of `name` |
  | `severity` | Severity of failure, from `1`, critical, to `3`, informational | required |
  | `panic_guide_url` | URL for Ops to go to when check fails | required, but can default to config value |
  | `business_impact` | What business process will be impacted if check fails | required, but can default to config value |
  | `technical_summary` | What has gone wrong, technically, if check fails | required, but can default to config value |
  | `initial_delay_ms` | Number of milliseconds to wait before running first check | defaults from config |
  | `period_ms` | Number of milliseconds to wait between runs of the same check | defaults from config |
  | `timeout_ms` | Number of milliseconds to wait before timing-out a running check | defaults from config |

  """

  defstruct [
    :id,
    :name,
    :description,
    :severity,
    :panic_guide_url,
    :business_impact,
    :technical_summary,
    :initial_delay_ms,
    :period_ms,
    :timeout_ms
  ]

  @type severity :: 1 | 2 | 3

  @type t :: %__MODULE__{
    id: String.t,
    name: String.t,
    description: String.t,
    severity: severity,
    panic_guide_url: String.t,
    business_impact: String.t,
    technical_summary: String.t,
    initial_delay_ms: non_neg_integer,
    period_ms: non_neg_integer,
    timeout_ms: non_neg_integer
  }

end
