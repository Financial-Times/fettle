defmodule Fettle.Config do
  @moduledoc """
  Processes configuration for healthchecks into internal structures.

  The `:ft_health` OTP application expects to find configuration under its OTP name,
  with at least the mandatory fields specified. e.g.

  ```
    config :ft_health,
      system_code: :ft_health_test, # NB mandatory
      name: "FT Health Application",
      description: "Runs healthchecks",
      panic_guide_url: "https://stackoverflow.com",
      initial_delay_ms: 1_000,
      check_period_ms: 30_000,
      check_timeout_ms: 2_000,
      checks: [ ... ]
  ```

  | Key | Description | Required or Defaults |
  | ----- | ----------- | -------------------- |
  | `system_code` | System code for report | Required |
  | `schema` | Module for report generation | default `Fettle.Schema.FTHealthCheckV1` |
  | `name` | Human-readable name of system | defaults to `system_code` |
  | `description` | Human-readable description of system | defaults to `system_code` |
  | `initial_delay_ms` | Number of milliseconds to wait before running first check | defaults to `0` |
  | `check_period_ms` | Number of milliseconds to wait between runs of the same check | defaults to `30_000` |
  | `timeout_ms` | Number of milliseconds to wait before timing-out a running check | defaults to `5000` |
  | `panic_guide_url` | A default URL for health check panic guides if not specified | Only required if not configured for each check |
  | `business_impact` | A default description for health checks if not specified | Only required if not configured for each check |
  | `technical_summary` | A default description for health checks if not specified | Only required if not configured for each check |
  | `checks` | An array of pre-configured health-check tuples | Optional |
  """

  alias Fettle.Spec

  @default_period_ms 30_000
  @default_initial_delay_ms 0
  @default_timeout_ms 5_000

  defstruct [
    :system_code,
    :name,
    :description,
    :schema,
    :period_ms,
    :initial_delay_ms,
    :timeout_ms,
    :panic_guide_url,
    :business_impact,
    :technical_summary
  ]

  @typedoc "top-level configuration for global settings and check defaults"
  @type t :: %__MODULE__{
    system_code: atom | String.t,
    name: String.t,
    description: String.t,
    schema: atom, # module implementing Fettle.Schema.Api
    initial_delay_ms: integer, # initial delay before starting any checks
    period_ms: integer, # period between checks
    timeout_ms: integer, # check timeout
    panic_guide_url: String.t, # default or base URL for relative url on checks
    business_impact: String.t, # default for checks
    technical_summary: String.t # default for checks
  }

  @typedoc """
  a check's configuration.

  `options` will be supplied to check runner; `options[:args]` will be passed to checker module's check function.
  """
  @type spec_and_fun :: {Spec.t, function, options :: Keyword.t}

  @spec to_app_config(map) :: __MODULE__.t
  def to_app_config(map) do

    config = struct(%__MODULE__{}, map)

    config
    |> ensure_keys!([:system_code])
    |> default_keys([
      name: config.system_code,
      description: config.system_code,
      schema: Fettle.Schema.FTHealthCheckV1,
      initial_delay_ms: @default_initial_delay_ms,
      period_ms: @default_period_ms,
      timeout_ms: @default_timeout_ms
    ])
  end

  @doc """
  Convert a health check specification from config into a `Fettle.Spec` spec, with module and opts.

  Config specifies each check as a 3-tuple of health-check metadata, implementation module and options;
  or a 2-tuple of the first two.

  Some fields of the check can be omitted, and the default value from the top-level config will be used
  instead; this applies to all fields except `name`, `full_name`, `id` and `severity`; if `id` is omitted, `name`
  will be used, if `full_name` is omitted, `name` will be used; `severity` defaults to `1`.

  `panic_guide_url` has special behavior, in that if a path starting with `#` or `/` is given, then
  this is appended to the `panic_guide_url` in the top-level configuration properties.
  ```
  config :health,
    system_code: "service-a",
    schema: Fettle.Schema.FTHealthCheckV1,
    panic_guide_url: "http://co.com/docs/service/healthchecks",
    technical_summary: "We'll spend all week repairing the damage.",
    checks: [
      {
        %{
          name: "service-b", # also provides id
          # full_name will be name
          panic_guide_url: "#service-b", # appended to top-level url
          # technical_summary from top-level
          business_impact: "No sales",
        },
        MyHealth.Spec, # implementation module name
        [
          period_ms: 10_000, # override default for this check only
          args: [url: "https://service-b.co.com/__gtg"]
        ]
      }
    ]
  ```
  """
  @spec check_from_config({map(), atom} | {map(), atom, Keyword.t}, config :: __MODULE__.t) :: {%Spec{}, atom, Keyword.t}
  def check_from_config(healthcheck, config)

  def check_from_config({healthcheck, module}, config = %__MODULE__{}), do: check_from_config({healthcheck, module, []}, config)

  def check_from_config({healthcheck, module, options}, config = %__MODULE__{}) when not is_nil(module) and is_atom(module) do

    spec = struct(%Spec{}, healthcheck)

    spec =
      spec
      |> default_keys(
          severity: 1,
          business_impact: config.business_impact,
          technical_summary: config.technical_summary,
          panic_guide_url: config.panic_guide_url
        )
      |> (fn spec ->
          {_val, spec} = Map.get_and_update(spec, :panic_guide_url, fn val ->
            {val, interpolate_panic_guide_url(val, config.panic_guide_url)}
          end)
          spec
        end).()
      |> ensure_keys!([
        :name,
        :severity,
        :panic_guide_url,
        :business_impact,
        :technical_summary
        ])
      |> default_keys(
        id: spec.name,
        description: spec.name
      )

    {
      spec,
      check_module_is_checker!(module),
      options || []
    }
  end

  def check_module_is_checker!(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        case Kernel.function_exported?(module, :check, 1) do
          true -> module
          false -> raise ArgumentError, "Module #{module} does not comply to Fettle.Checker behaviour (no check/1 function)"
        end
      {:error, error} -> raise ArgumentError, "Cannot load module #{module}: #{error}"
    end
  end

  def interpolate_panic_guide_url(nil, app_url), do: app_url
  def interpolate_panic_guide_url("#" <> check_url, app_url) when not is_nil(app_url), do: app_url <> "#" <> check_url
  def interpolate_panic_guide_url("/" <> check_url, app_url) when not is_nil(app_url), do: app_url <> "/" <> check_url
  def interpolate_panic_guide_url(check_url, _app_url), do: check_url

  @doc "ensure required keys are not missing, null, or empty strings"
  @spec ensure_keys!(config :: map, required_keys :: list) :: map | no_return
  def ensure_keys!(config, required_keys) when is_map(config) and is_list(required_keys) do
    Enum.each(required_keys, fn key ->
        case config do
          %{^key => val} when is_nil(val) -> raise ArgumentError, "config #{key} required"
          %{^key => ""} -> raise ArgumentError, "non-empty value for config #{key} required"
          %{^key => _val} -> :ok
        end
    end)
    config
  end

  @doc "default missing, nil or empty keys to matching values in keyword list"
  @spec default_keys(config :: map, key_defaults :: Keyword.t) :: map
  def default_keys(config, key_defaults) when is_map(config) and is_list(key_defaults) do
    Enum.reduce(key_defaults, config, fn
      ({key, default}, acc) ->
        {_, acc} = Map.get_and_update(acc, key, fn
          nil -> {nil, default}
          "" -> {"", default}
          existing -> {existing, existing}
        end)
        acc
    end)
  end

end
