defmodule Definitively.Nodes.ExecutorRouterTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Nodes.{Cli, ExecutorRouter, Llm}

  test "routes cli and llm kinds" do
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :cli}) == Cli
    assert ExecutorRouter.module_for(%NodeDefinition{kind: :llm}) == Llm
  end
end
