defmodule Orchestrator.Spec.LoaderTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.{NodeDefinition, Program, StateDefinition}
  alias Orchestrator.Spec.Loader

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)

  test "loads dev_quality_loop fixture" do
    assert {:ok, %Program{} = program} = Loader.load(@fixture)

    assert program.id == "dev_quality_loop"
    assert program.version == 1
    assert program.initial == :idle
    assert map_size(program.states) == 6
    assert map_size(program.nodes) == 3
  end

  test "parses active state with node ref" do
    {:ok, program} = Loader.load(@fixture)

    assert %StateDefinition{type: :active, node: :mix_credo} = program.states[:lint]
    assert {:ok, %NodeDefinition{kind: :cli}} = Program.active_node(program, :lint)
  end

  test "parses outcome predicates on nodes" do
    {:ok, program} = Loader.load(@fixture)

    assert [%{exit_code: 0}] = program.nodes[:mix_credo].outcome[:success]
    assert [%{timeout: true}, %{signal: "refused"}] = program.nodes[:llm_fix].outcome[:failure]
  end

  test "returns error for missing file" do
    assert {:error, %{reason: :invalid_yaml}} = Loader.load("/nonexistent/program.yml")
  end
end
