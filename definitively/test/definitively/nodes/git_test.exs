defmodule Definitively.Nodes.GitTest do
  use ExUnit.Case

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Nodes.Git
  alias Definitively.Workflow.RunContext

  setup do
    tmp = Path.join(System.tmp_dir!(), "definitively-git-#{System.unique_integer()}")
    File.mkdir_p!(tmp)
    System.cmd("git", ["init", "-b", "main"], cd: tmp, stderr_to_stdout: true)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: tmp)
    System.cmd("git", ["config", "user.name", "Test"], cd: tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  test "status on clean repo", %{tmp: tmp} do
    node = %NodeDefinition{id: :status, kind: :git, action: :status, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} = Git.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.signals[:clean]
    assert raw.data["clean"]
  end

  test "commit after modifying file", %{tmp: tmp} do
    File.write!(Path.join(tmp, "a.txt"), "hello")

    node = %NodeDefinition{
      id: :commit,
      kind: :git,
      action: :commit,
      options: %{"message" => "add a", "add" => "all"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Git.execute(node, ctx)
    assert raw.exit_code == 0
  end

  test "rejects non-git nodes" do
    node = %NodeDefinition{id: :x, kind: :cli, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:error, {:unsupported_kind, :cli}} = Git.execute(node, ctx)
  end
end
