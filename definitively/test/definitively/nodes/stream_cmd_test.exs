defmodule Definitively.Nodes.StreamCmdTest do
  use ExUnit.Case, async: false

  alias Definitively.Log.RunFile
  alias Definitively.Nodes.StreamCmd

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

  test "run mirrors subprocess output to active run log" do
    System.put_env("DEFINITIVELY_RUN_LOG", "1")
    tmp = Path.join(System.tmp_dir!(), "stream_cmd_log_#{System.unique_integer()}")
    program = Path.join([tmp, ".definitively", "programs", "probe.yml"])
    File.mkdir_p!(Path.dirname(program))

    on_exit(fn -> File.rm_rf(tmp) end)

    RunFile.with_log(tmp, program, [workspace_root: tmp], fn _opts ->
      assert {:ok, {"probe-output\n", 0, _ms}} =
               StreamCmd.run("sh", ["-c", "echo probe-output"], cd: tmp, timeout_ms: 5_000)

      :ok
    end)

    [log_file] = File.ls!(Path.join([tmp, ".definitively", "logs"]))
    content = File.read!(Path.join([tmp, ".definitively", "logs", log_file]))
    assert content =~ "probe-output\n"
  end
end
