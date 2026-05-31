defmodule Definitively.Domain.NodeDefinitionTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.NodeDefinition

  doctest NodeDefinition

  test "kinds/0 returns cli and llm" do
    assert NodeDefinition.kinds() == [:cli, :llm, :git, :gh]
  end
end
