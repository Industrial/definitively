defmodule Definitively.MixProject do
  use Mix.Project

  @github_repo "https://github.com/Industrial/definitively"

  def project do
    [
      app: :definitively,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      description: "FSM workflow orchestrator for CLI and LLM tasks",
      test_coverage: [
        tool: LcovEx,
        output: "cover",
        summary: [threshold: 90],
        ignore_modules: [Definitively.CLI]
      ],
      docs: docs(),
      package: package(),
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Definitively.Application, []}
    ]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},
      {:graphvix, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:lcov_ex, "~> 0.3", only: :test}
    ]
  end

  defp escript do
    [main_module: Definitively.CLI, name: "definitively"]
  end

  defp docs do
    [
      main: "Definitively",
      source_ref: "v#{Mix.Project.config()[:version]}",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      name: "definitively",
      files: ~w(lib priv config mix.exs mix.lock README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @github_repo},
      maintainers: ["Tom Wieland"]
    ]
  end
end
