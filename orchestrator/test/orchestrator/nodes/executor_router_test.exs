defmodule Orchestrator.Nodes.ExecutorRouterTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.NodeDefinition
  alias Orchestrator.Nodes.{Cli, ExecutorRouter, Llm}

  test "routes cli and llm kinds" do
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :cli}) == Cli
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :llm}) == Llm
  end
end
