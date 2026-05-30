defmodule Orchestrator.Nodes.CliTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.NodeDefinition
  alias Orchestrator.Nodes.Cli
  alias Orchestrator.Workflow.RunContext

  test "executes a command and captures exit code" do
    node = %NodeDefinition{
      id: :echo,
      kind: :cli,
      command: ["sh", "-c", "echo hi && exit 0"],
      cwd: nil,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t1", workspace_root: File.cwd!(), env: %{}}

    assert {:ok, %{exit_code: 0, stdout: "hi\n"}} = Cli.execute(node, ctx)
  end

  test "captures non-zero exit code" do
    node = %NodeDefinition{
      id: :fail,
      kind: :cli,
      command: ["sh", "-c", "exit 2"],
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t1", workspace_root: File.cwd!(), env: %{}}
    assert {:ok, %{exit_code: 2}} = Cli.execute(node, ctx)
  end

  test "rejects non-cli nodes" do
    node = %NodeDefinition{id: :x, kind: :llm, outcome: %{}}
    ctx = %RunContext{run_id: "t1", workspace_root: ".", env: %{}}
    assert {:error, {:unsupported_kind, :llm}} = Cli.execute(node, ctx)
  end
end
