defmodule Orchestrator.Domain.NodeDefinitionTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.NodeDefinition

  doctest NodeDefinition

  test "kinds/0 returns cli and llm" do
    assert NodeDefinition.kinds() == [:cli, :llm]
  end
end
