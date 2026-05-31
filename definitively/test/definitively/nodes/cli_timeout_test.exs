defmodule Definitively.Nodes.CliTimeoutTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Nodes.Cli
  alias Definitively.Workflow.RunContext

  test "reports timeout when command exceeds limit" do
    node = %NodeDefinition{
      id: :slow,
      kind: :cli,
      command: ["sh", "-c", "sleep 1"],
      timeout_ms: 1,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t1", workspace_root: File.cwd!(), env: %{}}

    assert {:ok, %{timed_out: true}} = Cli.execute(node, ctx)
  end
end
