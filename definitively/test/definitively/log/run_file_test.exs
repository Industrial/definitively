defmodule Definitively.Log.RunFileTest do
  use ExUnit.Case, async: false

  alias Definitively.Log
  alias Definitively.Log.RunFile
  alias Definitively.Run.Coordinator

  @fixture Path.expand("../../fixtures/echo_ok.yml", __DIR__)

  setup do
    on_exit(fn ->
      System.delete_env("DEFINITIVELY_RUN_LOG")
      RunFile.clear_run_log_path!()
    end)

    :ok
  end

  test "log_path uses program id and timestamp suffix" do
    path = RunFile.log_path("/tmp/ws", @fixture)

    assert String.starts_with?(path, "/tmp/ws/.definitively/logs/")
    assert String.ends_with?(path, "-echo_ok.log")
    assert path =~ ~r/logs\/\d{8}-\d{6}-echo_ok\.log$/
  end

  test "with_log writes definitively logger output to file" do
    tmp = Path.join(System.tmp_dir!(), "orch_run_log_#{System.unique_integer()}")
    logs_dir = Path.join([tmp, ".definitively", "logs"])
    programs = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(programs)
    program = Path.join(programs, "echo_ok.yml")
    File.cp!(@fixture, program)

    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.put_env("DEFINITIVELY_WORKSPACE", tmp)
    System.put_env("DEFINITIVELY_LOG_LEVEL", "INFO")
    Log.configure!()

    on_exit(fn ->
      File.rm_rf(tmp)

      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        v -> System.put_env("DEFINITIVELY_WORKSPACE", v)
      end
    end)

    assert :ok =
             RunFile.with_log(tmp, program, fn ->
               Coordinator.run_until_final(program, workspace_root: tmp)
             end)

    [log_file | _] = File.ls!(logs_dir)
    content = File.read!(Path.join(logs_dir, log_file))

    assert log_file =~ "-echo_ok.log"
    assert content =~ "run log opened"
    assert content =~ "run started"
    assert content =~ "run finished"
  end

  test "with_log can be disabled via DEFINITIVELY_RUN_LOG=0" do
    tmp = Path.join(System.tmp_dir!(), "orch_run_log_off_#{System.unique_integer()}")
    programs = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(programs)
    program = Path.join(programs, "echo_ok.yml")
    File.cp!(@fixture, program)
    System.put_env("DEFINITIVELY_RUN_LOG", "0")

    on_exit(fn -> File.rm_rf(tmp) end)

    assert :ok =
             RunFile.with_log(tmp, program, fn ->
               Coordinator.run_until_final(program, workspace_root: tmp)
             end)

    refute File.exists?(Path.join([tmp, ".definitively", "logs"]))
  end
end
