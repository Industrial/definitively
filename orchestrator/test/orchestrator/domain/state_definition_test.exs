defmodule Orchestrator.Domain.StateDefinitionTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.StateDefinition

  test "types/0 returns all FSM state types" do
    assert StateDefinition.types() == [:passive, :active, :approval, :final]
  end
end
