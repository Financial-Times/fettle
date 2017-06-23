defmodule Fettle.Mixfile do
  use Mix.Project

  def project do
    [app: :fettle,
     version: "0.1.0",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: [test: "test --no-start"],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Fettle.Application, []}]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
     {:deferred_config, "~> 0.1.0"},
     {:credo, "~> 0.5", only: [:dev, :test]},
     {:mix_test_watch, "~> 0.3", only: :dev, runtime: false},
     {:ex_doc, "~> 0.14", only: :dev, runtime: false},
     {:dialyxir, "~> 0.5.0", only: [:dev], runtime: false}
    ]
  end
end
