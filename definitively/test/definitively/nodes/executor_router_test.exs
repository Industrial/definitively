defmodule Definitively.Nodes.ExecutorRouterTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Nodes.{Cli, ExecutorRouter, Gh, Git, Llm, Maestro}

  test "routes all node kinds" do
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :cli}) == Cli
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :llm}) == Llm
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :git}) == Git
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :gh}) == Gh
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :maestro}) == Maestro
  end
end
