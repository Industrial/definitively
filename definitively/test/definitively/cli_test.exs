defmodule Definitively.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Definitively.CLI

  @fixture Path.expand("../fixtures/echo_ok.yml", __DIR__)
  @approval Path.expand("../fixtures/approval_state.yml", __DIR__)

  test "dispatch run completes echo_ok program" do
    assert :ok = CLI.dispatch(["run", @fixture])
  end

  test "dispatch run auto-approves approval_state" do
    assert :ok = CLI.dispatch(["run", @approval])
  end

  test "dispatch returns usage for unknown command" do
    assert :usage = CLI.dispatch(["nope"])
  end

  test "dispatch returns usage for removed status command" do
    assert :usage = CLI.dispatch(["status", "run-1"])
  end

  test "dispatch returns usage for removed approve command" do
    assert :usage = CLI.dispatch(["approve", "run-1", "done"])
  end

  test "dispatch run reports missing program" do
    assert {:error, _, 1} = CLI.dispatch(["run", "/nonexistent/program.yml"])
  end

  test "dispatch visualize prints output file paths" do
    with_workspace_program(@fixture, fn program, workspace ->
      dot_path = Path.join([workspace, ".definitively", "visualizations", "echo_ok.dot"])

      if System.find_executable("dot") do
        output = capture_io(fn -> assert :ok = CLI.dispatch(["visualize", program]) end)
        assert output =~ dot_path
        assert output =~ ".png"
        refute output =~ "digraph"
        assert File.read!(dot_path) =~ "idle"
      else
        assert {:error, {:graphviz_unavailable, _, [dot_path: ^dot_path]}, 1} =
                 CLI.dispatch(["visualize", program])

        assert File.read!(dot_path) =~ "idle"
      end
    end)
  end

  test "dispatch visualize missing program" do
    assert {:error, _, 1} = CLI.dispatch(["visualize", "/nonexistent/program.yml"])
  end

  test "dispatch visualize accepts format flag" do
    with_workspace_program(@fixture, fn program, workspace ->
      dot_path = Path.join([workspace, ".definitively", "visualizations", "echo_ok.dot"])

      output =
        capture_io(fn ->
          assert :ok = CLI.dispatch(["visualize", program, "--format", "dot"])
        end)

      assert output =~ dot_path
      refute output =~ "digraph"
    end)
  end

  test "run completes echo_ok program via main" do
    assert capture_io(fn -> CLI.main(["run", @fixture]) end) =~ "workflow finished"
  end

  test "mix definitively task delegates to CLI" do
    assert capture_io(fn -> Mix.Task.run("definitively", ["run", @fixture]) end) =~
             "workflow finished"
  end

  test "dispatch run reports no_definitively_layout" do
    tmp = System.tmp_dir!()
    path = Path.join(tmp, "standalone.yml")

    File.write!(
      path,
      "program:\n  id: x\n  version: 1\n  initial: idle\nstates: {}\nnodes: {}\n"
    )

    on_exit(fn -> File.rm(path) end)

    without_workspace_env(fn ->
      assert {:error, :no_definitively_layout, 1} = CLI.dispatch(["run", path])
    end)
  end

  test "dispatch run reports invalid_start" do
    minimal = Path.expand("../fixtures/minimal_passive.yml", __DIR__)
    assert {:error, :invalid_start, 1} = CLI.dispatch(["run", minimal])
  end

  test "dispatch visualize without path returns usage" do
    assert :usage = CLI.dispatch(["visualize"])
  end

  test "dispatch run stops at approval without auto label" do
    path = Path.expand("../fixtures/reject_only.yml", __DIR__)
    assert {:error, :awaiting_approval, 2} = CLI.dispatch(["run", path])
  end

  test "dispatch visualize invalid yaml" do
    with_workspace_program(
      Path.expand("../fixtures/missing_program.yml", __DIR__),
      fn program, _workspace ->
        assert {:error, _, 1} = CLI.dispatch(["visualize", program])
      end
    )
  end

  test "main visualize prints output file paths" do
    if System.find_executable("dot") do
      with_workspace_program(@fixture, fn program, workspace ->
        dot_path = Path.join([workspace, ".definitively", "visualizations", "echo_ok.dot"])

        output = capture_io(fn -> assert :ok = CLI.main(["visualize", program]) end)

        assert output =~ dot_path
        refute output =~ "digraph"
      end)
    end
  end

  test "dispatch cancel command is removed" do
    assert :usage = CLI.dispatch(["cancel", "run-1"])
  end

  test "dispatch visualize png without dot reports error" do
    unless System.find_executable("dot") do
      with_workspace_program(@fixture, fn program, _workspace ->
        assert {:error, {:graphviz_unavailable, _}, 1} =
                 CLI.dispatch(["visualize", program, "--format", "png", "--out", "orch_test_out"])
      end)
    end
  end

  test "dispatch run generic error from invalid_start surfaces code 1" do
    minimal = Path.expand("../fixtures/minimal_passive.yml", __DIR__)
    assert {:error, :invalid_start, 1} = CLI.dispatch(["run", minimal])
  end

  test "dispatch visualize writes png path when dot exists" do
    if System.find_executable("dot") do
      with_workspace_program(@fixture, fn program, _workspace ->
        tmp = System.tmp_dir!()
        out = Path.join(tmp, "orch_cli_viz")

        output =
          capture_io(fn ->
            assert :ok = CLI.dispatch(["visualize", program, "--format", "png", "--out", out])
          end)

        assert output =~ ".png"
        File.rm(out <> ".png")
      end)
    end
  end

  test "dispatch visualize spec error message" do
    with_workspace_program(
      Path.expand("../fixtures/missing_program.yml", __DIR__),
      fn program, _workspace ->
        assert {:error, msg, 1} = CLI.dispatch(["visualize", program])
        assert is_binary(msg)
      end
    )
  end

  test "dispatch visualize out flag only uses dot" do
    with_workspace_program(@fixture, fn program, _workspace ->
      tmp = System.tmp_dir!()
      out = Path.join(tmp, "orch_cli_out_only")
      dot_path = out <> ".dot"

      output =
        capture_io(fn ->
          assert :ok = CLI.dispatch(["visualize", program, "--out", out])
        end)

      assert output =~ dot_path
      refute output =~ "digraph"
      File.rm(dot_path)
    end)
  end

  test "dispatch run fails for invalid program under definitively layout" do
    tmp = Path.join(System.tmp_dir!(), "orch_cli_ws_#{System.unique_integer()}")
    orch = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(orch)
    bad = Path.join(orch, "bad.yml")
    File.cp!(Path.expand("../fixtures/missing_program.yml", __DIR__), bad)

    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.put_env("DEFINITIVELY_WORKSPACE", tmp)

    on_exit(fn ->
      File.rm_rf(tmp)

      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        v -> System.put_env("DEFINITIVELY_WORKSPACE", v)
      end
    end)

    assert {:error, _, 1} = CLI.dispatch(["run", bad])
  end

  test "dispatch run --help lists declared inputs" do
    with_workspace_program(Path.expand("../fixtures/with_inputs.yml", __DIR__), fn program,
                                                                                   _workspace ->
      output = capture_io(fn -> assert :ok = CLI.dispatch(["run", "--help", program]) end)
      assert output =~ "with_inputs"
      assert output =~ "--plan-file"
    end)
  end

  test "dispatch run accepts declared inputs and completes" do
    with_workspace_program(Path.expand("../fixtures/with_inputs.yml", __DIR__), fn program,
                                                                                   _workspace ->
      assert :ok = CLI.dispatch(["run", program, "--plan-file", "plans/x.md"])
    end)
  end

  test "dispatch run rejects missing required input" do
    with_workspace_program(Path.expand("../fixtures/with_inputs.yml", __DIR__), fn program,
                                                                                   _workspace ->
      assert {:error, {:missing_required, ["--plan-file"]}, 1} = CLI.dispatch(["run", program])
    end)
  end

  test "dispatch run rejects unknown flag on program without inputs" do
    assert {:error, {:unknown_flag, "--nope", _known}, 1} =
             CLI.dispatch(["run", @fixture, "--nope", "x"])
  end

  defp with_workspace_program(fixture, fun) do
    tmp = Path.join(System.tmp_dir!(), "orch_cli_ws_#{System.unique_integer()}")
    programs = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(programs)
    program = Path.join(programs, Path.basename(fixture))
    File.cp!(fixture, program)

    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.put_env("DEFINITIVELY_WORKSPACE", tmp)

    on_exit(fn ->
      File.rm_rf(tmp)

      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        v -> System.put_env("DEFINITIVELY_WORKSPACE", v)
      end
    end)

    fun.(program, tmp)
  end

  defp without_workspace_env(fun) do
    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.delete_env("DEFINITIVELY_WORKSPACE")

    try do
      fun.()
    after
      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        value -> System.put_env("DEFINITIVELY_WORKSPACE", value)
      end
    end
  end

  test "dispatch version prints package version" do
    output = capture_io(fn -> assert :ok = CLI.dispatch(["version"]) end)
    assert output == "definitively " <> Definitively.Version.version() <> "\n"
  end

  test "main --version prints package version without starting workflow" do
    output = capture_io(fn -> assert :ok = CLI.main(["--version"]) end)
    assert output == "definitively " <> Definitively.Version.version() <> "\n"
  end

  test "main -V prints package version" do
    output = capture_io(fn -> assert :ok = CLI.main(["-V"]) end)
    assert output == "definitively " <> Definitively.Version.version() <> "\n"
  end

end
