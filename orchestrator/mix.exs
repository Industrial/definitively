defmodule Orchestrator.MixProject do
  use Mix.Project

  @github_repo "https://github.com/tomwieland/test-haskell-web"

  def project do
    [
      app: :orchestrator,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      description: "FSM workflow orchestrator for CLI and LLM tasks",
      test_coverage: [summary: [threshold: 90], ignore_modules: [Orchestrator.CLI]],
      docs: docs(),
      package: package(),
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Orchestrator.Application, []}
    ]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},
      {:graphvix, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp escript do
    [main_module: Orchestrator.CLI, name: "orchestrator"]
  end

  defp docs do
    [
      main: "Orchestrator",
      source_ref: "v#{Mix.Project.config()[:version]}",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      name: "orchestrator",
      files: ~w(lib priv config mix.exs mix.lock README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @github_repo},
      maintainers: ["Tom Wieland"]
    ]
  end
end
