defmodule Fettle.Mixfile do
  use Mix.Project

  def project do
    [
      app: :fettle,
      version: "1.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/Financial-Times/fettle",
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def package do
    [
      maintainers: ["Ellis Pritchard"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/Financial-Times/fettle"}
    ]
  end

  defp description do
    """
    Runs health-check functions periodically, and aggregates health status reports.
    """
  end

  def docs do
    [main: "readme", extras: ["README.md"]]
  end

  defp deps do
    [
      {:deferred_config, "~> 0.1.1"},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0.2", only: :dev, runtime: false},
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:inch_ex, "~> 2.0", only: :docs}
    ]
  end
end
