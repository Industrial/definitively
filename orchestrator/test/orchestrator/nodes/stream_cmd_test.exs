defmodule Orchestrator.Nodes.StreamCmdTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Nodes.StreamCmd

  test "resolve_executable finds sh on PATH" do
    path = StreamCmd.resolve_executable("sh")
    assert is_binary(path)
    assert File.exists?(path)
  end

  test "run streams and captures output" do
    assert {:ok, {"hello\n", 0, _ms}} =
             StreamCmd.run("sh", ["-c", "echo hello"], cd: File.cwd!(), timeout_ms: 5_000)
  end

  test "run reports timeout" do
    assert {:ok, {:timed_out, _, ms}} =
             StreamCmd.run("sh", ["-c", "sleep 2"], cd: File.cwd!(), timeout_ms: 50)

    assert ms >= 50
  end
end
