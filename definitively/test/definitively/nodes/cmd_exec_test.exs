defmodule Definitively.Nodes.CmdExecTest do
  use ExUnit.Case, async: true

  alias Definitively.Nodes.CmdExec

  setup do
    {:ok, cwd: File.cwd!()}
  end

  test "run reports timeout", %{cwd: cwd} do
    assert {:ok, {:timed_out, raw}} =
             CmdExec.run("sh", ["-c", "sleep 2"], cd: cwd, timeout_ms: 50)

    assert raw.timed_out
  end

  test "run_argv runs nested argvs sequentially", %{cwd: cwd} do
    assert {:ok, raw} =
             CmdExec.run_argv("sh", [["-c", "echo first"], ["-c", "echo second"]],
               cd: cwd,
               timeout_ms: 5_000
             )

    assert raw.exit_code == 0
    assert raw.stdout =~ "second"
  end

  test "run_argv multi halts on non-zero exit", %{cwd: cwd} do
    assert {:ok, raw} =
             CmdExec.run_argv("sh", [["-c", "exit 3"], ["-c", "echo never"]],
               cd: cwd,
               timeout_ms: 5_000
             )

    assert raw.exit_code == 3
  end

  test "run_argv multi halts on timeout", %{cwd: cwd} do
    assert {:ok, raw} =
             CmdExec.run_argv("sh", [["-c", "sleep 2"], ["-c", "echo never"]],
               cd: cwd,
               timeout_ms: 50
             )

    assert raw.timed_out
  end

  test "run_argv accepts {:multi, argvs}", %{cwd: cwd} do
    assert {:ok, raw} =
             CmdExec.run_argv("sh", {:multi, [["-c", "echo ok"]]}, cd: cwd, timeout_ms: 5_000)

    assert raw.exit_code == 0
    assert raw.stdout =~ "ok"
  end
end
