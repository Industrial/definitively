defmodule Definitively.Spec.LoaderTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.{NodeDefinition, Program, StateDefinition}
  alias Definitively.Spec.Loader

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

  test "returns error for missing program section" do
    path = fixture("missing_program.yml")
    assert {:error, %{reason: :invalid_program}} = Loader.load(path)
  end

  test "returns error for missing states section" do
    path = fixture("missing_states.yml")
    assert {:error, %{reason: :missing_states}} = Loader.load(path)
  end

  test "returns error for invalid initial state" do
    path = fixture("invalid_initial.yml")
    assert {:error, %{reason: :invalid_initial}} = Loader.load(path)
  end

  test "returns error for invalid state type" do
    path = fixture("invalid_state_type.yml")
    assert {:error, %{reason: :invalid_state_type}} = Loader.load(path)
  end

  test "returns error when active state lacks node ref" do
    path = fixture("active_missing_node.yml")
    assert {:error, %{reason: :missing_node_ref}} = Loader.load(path)
  end

  test "returns error when active state references undefined node" do
    path = fixture("undefined_node_ref.yml")
    assert {:error, %{reason: :undefined_node}} = Loader.load(path)
  end

  test "returns error for invalid node kind" do
    path = fixture("invalid_node_kind.yml")
    assert {:error, %{reason: :invalid_node_kind}} = Loader.load(path)
  end

  test "returns error for invalid command shape" do
    path = fixture("invalid_command.yml")
    assert {:error, %{reason: :invalid_command}} = Loader.load(path)
  end

  test "returns error for invalid outcome section" do
    path = fixture("invalid_outcome.yml")
    assert {:error, %{reason: :invalid_outcome}} = Loader.load(path)
  end

  test "loads programs without explicit nodes section" do
    path = fixture("minimal_passive.yml")
    assert {:ok, %Program{nodes: nodes, initial: :idle}} = Loader.load(path)
    assert nodes == %{}
  end

  test "loads approval state type" do
    path = fixture("approval_state.yml")
    assert {:ok, %Program{states: states}} = Loader.load(path)
    assert states[:idle].type == :approval
  end

  test "returns error for malformed yaml" do
    path = Path.join(System.tmp_dir!(), "definitively-malformed-#{System.unique_integer()}.yml")
    File.write!(path, "[unclosed")

    on_exit(fn -> File.rm(path) end)

    assert {:error, %{reason: :invalid_yaml}} = Loader.load(path)
  end

  test "returns error for invalid states shape" do
    assert {:error, %{reason: :invalid_states}} = Loader.load(fixture("invalid_states.yml"))
  end

  test "returns error for invalid nodes shape" do
    assert {:error, %{reason: :invalid_nodes}} = Loader.load(fixture("invalid_nodes.yml"))
  end

  test "returns error for invalid on map" do
    assert {:error, %{reason: :invalid_on}} = Loader.load(fixture("invalid_on.yml"))
  end

  test "returns error for invalid state definition" do
    assert {:error, %{reason: :invalid_state}} = Loader.load(fixture("invalid_state.yml"))
  end

  test "returns error for invalid node definition" do
    assert {:error, %{reason: :invalid_node}} = Loader.load(fixture("invalid_node.yml"))
  end

  test "returns error for invalid node ref type" do
    assert {:error, %{reason: :invalid_node_ref}} = Loader.load(fixture("invalid_node_ref.yml"))
  end

  test "returns error for invalid atom in transition target" do
    assert {:error, %{reason: :invalid_atom}} = Loader.load(fixture("invalid_atom.yml"))
  end

  test "returns error for invalid outcome clauses" do
    assert {:error, %{reason: :invalid_outcome_clauses}} =
             Loader.load(fixture("invalid_outcome_clauses.yml"))
  end

  test "returns error for invalid predicate clause" do
    assert {:error, %{reason: :invalid_predicate}} = Loader.load(fixture("invalid_predicate.yml"))
  end

  defp fixture(name), do: Path.expand("../../fixtures/#{name}", __DIR__)
end
