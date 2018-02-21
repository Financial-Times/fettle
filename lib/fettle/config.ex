defmodule Fettle.Config do
  @moduledoc """
  Processes configuration for healthchecks into internal structures.

  Configuration can be specified either by application configuration under the
  `:fettle` key, or by supplying via a module, function or inline argument
  to `Fettle.Supervisor.start_link/1`.

  ```
    config :fettle,
      system_code: :my_app, # NB mandatory
      name: "My Application",
      description: "My Application provides...",
      panic_guide_url: "https://stackoverflow.com",
      initial_delay_ms: 1_000,
      period_ms: 30_000,
      timeout_ms: 2_000,
      checks: [ ... ]
  ```
  The minimum configuration requires the `system_code` key:

  | Key | Description | Required or Defaults |
  | ----- | ----------- | -------------------- |
  | `system_code` | System code for report | Required |
  | `schema` | Module for report generation | `Fettle.Schema.FTHealthCheckV1` |
  | `name` | Human-readable name of system | defaults to `system_code` |
  | `description` | Human-readable description of system | defaults to `system_code` |
  | `initial_delay_ms` | Number of milliseconds to wait before running first check | `0` |
  | `period_ms` | Number of milliseconds to wait between runs of the same check | `30_000` |
  | `timeout_ms` | Number of milliseconds to wait before timing-out a running check | `5000` |
  | `panic_guide_url` | URL of documentation for check | <sup>1</sup> <sup>2</sup> |
  | `business_impact` | Which business function is affected? | <sup>1</sup> |
  | `technical_summary` | Technical description for Ops | <sup>1</sup> |
  | `checks` | An array of pre-configured health-check config | Optional, see `Fettle.add/3` <sup>3</sup> |

  1. Specifies default value for checks. Required only if not specified for every check.
  2. `panic_guide_url` can form the base-url for checks which specify a relative `panic_guide_url`.
  3. `checks` is an array, but each element can be specified as either a map,
     or a `Keyword` list (or any other `Enumerable` that yields key-value pairs).

  """

  alias Fettle.Spec

  @default_period_ms 30_000
  @default_initial_delay_ms 500
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

  @typedoc "Top-level configuration for global settings and check defaults (derived from app config)"
  @type t :: %__MODULE__{
    system_code: atom | String.t,
    name: atom | String.t,
    description: atom | String.t,
    schema: atom, # module implementing Fettle.Schema
    initial_delay_ms: integer, # initial delay before starting any checks
    period_ms: integer, # period between checks
    timeout_ms: integer, # check timeout
    panic_guide_url: String.t, # default or base URL for relative url on checks
    business_impact: String.t, # default for checks
    technical_summary: String.t # default for checks
  }

  @typedoc "Tuple which specifies a check (derived from app config)"
  @type spec_and_mod :: {Spec.t, module, init_args :: any}

  @doc "Parses configuration into `%Fettle.Config{}`"
  @spec to_app_config(map | list) :: __MODULE__.t
  def to_app_config(map_or_kws) do

    config = struct(%__MODULE__{}, map_or_kws)

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
    |> cast_to_integer([:initial_delay_ms, :period_ms, :timeout_ms])
  end

  @doc """
  Convert a single health check specification from config into a `Fettle.Spec` spec, with module and args.

  Each check is specified as a collection of key-value pairs:

  | Key | Type | Description | Default/Required |
  | --- | ---- | ----------- | ------- |
  | `name` | `String` | Name of check | required |
  | `id` | `String` | Short id of check | Defaults to `name` |
  | `description` | `String` | Longer description of check | Defaults to `name` |
  | `panic_guide_url` | `String` | URL of documentation for check | Defaults to config |
  | `business_impact` | `String` | Which business function is affected? | Defaults to config |
  | `technical_summary` | `String` | Technical description for Ops | Defaults to config |
  | `severity` | `1-3` | Severity level: 1 high, 3 low | Defaults to `1` |
  | `initial_delay_ms` | `integer` | Number of milliseconds to wait before running first check | Defaults to config |
  | `period_ms` | `integer` | Number of milliseconds to wait between runs of the check | Defaults to config |
  | `timeout_ms` | `integer` | Number of milliseconds to wait before timing-out check | Defaults to config |
  | `checker` | `atom` | `Fettle.Checker` module | Required |
  | `args` | `any` | passed as argument for `Fettle.Checker` module | defaults to [] |

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
      %{
        name: "service-b", # also provides id and full_name if those undefined
        panic_guide_url: "#service-b", # appended to top-level url
        # technical_summary will come from top-level
        business_impact: "No sales",
        period_ms: 10_000, # override default for this check only
        checker: MyHealth.Spec, # implementation module name
        args: [url: "https://service-b.co.com/__gtg"] # for `Fettle.Checker.check/1`
      },
      %{
        ...
      }
    ]
  ```
  """
  @spec check_from_config(check :: map | list, config :: __MODULE__.t) :: spec_and_mod
  def check_from_config(check, config)

  def check_from_config(check, config = %__MODULE__{}) when is_map(check) or is_list(check) do

    spec = struct(%Spec{}, check)

    spec =
      spec
      |> default_keys(
          severity: 1,
          business_impact: config.business_impact,
          technical_summary: config.technical_summary,
          panic_guide_url: config.panic_guide_url
        )
      |> interpolate_panic_guide_url(config)
      |> ensure_keys!([
        :name,
        :severity,
        :panic_guide_url,
        :business_impact,
        :technical_summary
        ])
      |> default_keys(
        id: spec.name,
        description: spec.name,
        initial_delay_ms: config.initial_delay_ms,
        period_ms: config.period_ms,
        timeout_ms: config.timeout_ms
      )
      |> cast_to_integer([:initial_delay_ms, :period_ms, :timeout_ms, :severity])
      |> check_range!(:severity, 1..3)
      |> check_non_negative!([:initial_delay_ms, :period_ms, :timeout_ms])


    module = check[:checker] || raise ArgumentError, "Missing checker module for check #{spec.id}."
    module = Fettle.Util.check_module_complies!(module, Fettle.Checker, {:check, 1})

    init_args = check[:args] || []

    {spec, module, init_args}
  end

  @doc "append path parts to top-level config `panic_guide_url` if relative path is given in checker."
  def interpolate_panic_guide_url(spec = %Spec{}, %__MODULE__{panic_guide_url: config_url}) do
    {_val, spec} =
      Map.get_and_update(spec, :panic_guide_url, fn
        val -> {val, interpolate_panic_guide_url(val, config_url)} end
      )
    spec
  end
  def interpolate_panic_guide_url(nil, config_url), do: config_url
  def interpolate_panic_guide_url("#" <> check_url, config_url) when is_binary(config_url), do: config_url <> "#" <> check_url
  def interpolate_panic_guide_url("/" <> check_url, config_url) when is_binary(config_url), do: config_url <> "/" <> check_url
  def interpolate_panic_guide_url(check_url, _config_url) when is_binary(check_url), do: check_url

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

  defp cast_to_integer(map, keys) do
    Enum.reduce(keys, map, fn key, m -> Map.update!(m, key, &to_integer/1) end)
  end

  defp to_integer(i) when is_integer(i), do: i
  defp to_integer("" <> i), do: String.to_integer(i)
  defp to_integer(nil), do: nil

  defp check_range!(map, key, range) do
    Enum.member?(range, Map.get(map, key)) || raise ArgumentError, "#{key} should be in range #{inspect range}: got #{Map.get(map,key)}"
    map
  end

  defp check_non_negative!(map, keys) when is_list(keys) do
    Enum.each(keys, fn key -> check_non_negative!(map, key) end)
    map
  end

  defp check_non_negative!(map, key) do
    (Map.get(map, key) >= 0) || raise ArgumentError, "#{key} should be zero or positive value: got #{Map.get(map,key)}"
    map
  end

end
