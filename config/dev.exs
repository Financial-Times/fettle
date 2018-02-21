use Mix.Config

config :logger, level: :debug

config :fettle,
  system_code: :fettle_dev,
  name: "Fettle Application",
  description: "Runs healthchecks",
  panic_guide_url: "https://stackoverflow.com",
  initial_delay_ms: 1_000,
  period_ms: {:system, "FETTLE_CHECK_PERIOD", 30_000, {String, :to_integer}},
  timeout_ms: 2_000,
  checks: [
    [
      name: "AlwaysHealthyCheck",
      full_name: "Demo passing health check",
      severity: 1,
      business_impact: "Firesale",
      technical_summary: "Panic",
      panic_guide_url: "https://stackoverflow.com",
      period_ms: 10_000,
      checker: Fettle.AlwaysHealthyCheck,
      args: [
        url: {:system, "NEVER_HEALTHY_URL", "https://twitter.com"}
      ]
    ],
    %{
      name: "NeverHealthyCheck",
      full_name: "Demo failing health check",
      severity: 1,
      business_impact: "Duck and cover",
      technical_summary: "SNAFU",
      panic_guide_url: "https://twitter.com",
      checker: Fettle.NeverHealthyCheck
    }
  ]
