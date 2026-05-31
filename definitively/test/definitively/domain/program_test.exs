defmodule Definitively.Domain.ProgramTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.{NodeDefinition, Program, StateDefinition}
  alias Definitively.Spec.Loader

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)

  test "final_states/1 lists final state names" do
    {:ok, program} = Loader.load(@fixture)
    assert Enum.sort(Program.final_states(program)) == [:done, :failed]
  end

  test "active_node/2 returns node for active states" do
    {:ok, program} = Loader.load(@fixture)
    assert {:ok, %NodeDefinition{id: :mix_credo}} = Program.active_node(program, :lint)
  end

  test "active_node/2 rejects passive and final states" do
    {:ok, program} = Loader.load(@fixture)

    assert {:error, :not_active} = Program.active_node(program, :idle)
    assert {:error, :not_active} = Program.active_node(program, :done)
  end

  test "active_node/2 rejects active state with missing node definition" do
    program = %Program{
      id: "test",
      version: 1,
      initial: :lint,
      states: %{lint: %StateDefinition{name: :lint, type: :active, node: :ghost, on: %{}}},
      nodes: %{}
    }

    assert {:error, :not_active} = Program.active_node(program, :lint)
  end
end
