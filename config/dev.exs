use Mix.Config

config :logger,
  level: :debug

config :fettle,
  system_code: :fettle_dev,
  name: "Fettle Application",
  description: "Runs healthchecks",
  panic_guide_url: "https://stackoverflow.com",
  initial_delay_ms: 1_000,
  check_period_ms: 30_000,
  check_timeout_ms: 2_000,
  checks: [
    {
      %{
        name: "AlwaysHealthyCheck",
        full_name: "Demo passing health check",
        severity: 1,
        business_impact: "Firesale",
        technical_summary: "Panic",
        panic_guide_url: "https://stackoverflow.com"
      },
      Fettle.AlwaysHealthyCheck
    },
    {
      %{
        name: "NeverHealthyCheck",
        full_name: "Demo failing health check",
        severity: 1,
        business_impact: "Duck and cover",
        technical_summary: "SNAFU",
        panic_guide_url: "https://twitter.com"
      },
      Fettle.NeverHealthyCheck
    }
  ]
