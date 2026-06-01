defmodule Definitively.Nodes.GitTest do
  use ExUnit.Case, async: false

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

  test "returns timed_out raw without parsing", %{tmp: tmp} do
    real_git = System.find_executable("git")
    bin = Path.join(tmp, "bin")
    File.mkdir_p!(bin)
    wrapper = Path.join(bin, "git")

    File.write!(
      wrapper,
      ~s(#!/bin/sh
if [ "$1" = "status" ]; then sleep 60; exit 0; fi
exec ) <> real_git <> ~s( "$@"
)
    )

    File.chmod!(wrapper, 0o755)
    prev = System.get_env("PATH") || ""
    System.put_env("PATH", bin <> ":" <> prev)
    on_exit(fn -> System.put_env("PATH", prev) end)

    node = %NodeDefinition{
      id: :status,
      kind: :git,
      action: :status,
      timeout_ms: 50,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Git.execute(node, ctx)
    assert raw.timed_out
    assert raw.signals == %{}
  end

  test "expands relative cwd under workspace root", %{tmp: tmp} do
    sub = Path.join(tmp, "nested")
    File.mkdir_p!(sub)
    real_git = System.find_executable("git")
    System.cmd(real_git, ["init", "-b", "main"], cd: sub, stderr_to_stdout: true)

    node = %NodeDefinition{
      id: :status,
      kind: :git,
      action: :status,
      cwd: ".",
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: sub, env: %{}}
    assert {:ok, raw} = Git.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.signals[:clean]
  end

  test "rejects non-git nodes" do
    node = %NodeDefinition{id: :x, kind: :cli, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:error, {:unsupported_kind, :cli}} = Git.execute(node, ctx)
  end
end
