defmodule Definitively.Nodes.CliTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Nodes.Cli
  alias Definitively.Workflow.RunContext

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

  test "expands relative cwd under workspace root" do
    tmp = System.tmp_dir!()

    node = %NodeDefinition{
      id: :pwd,
      kind: :cli,
      command: ["sh", "-c", "pwd"],
      cwd: ".",
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t1", workspace_root: tmp, env: %{}}
    assert {:ok, %{stdout: stdout}} = Cli.execute(node, ctx)
    assert String.trim(stdout) == Path.expand(".", tmp)
  end
end
