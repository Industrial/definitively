defmodule Orchestrator.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Orchestrator.CLI
  alias Orchestrator.Run.Coordinator

  @fixture Path.expand("../fixtures/echo_ok.yml", __DIR__)

  test "dispatch run completes echo_ok program" do
    assert :ok = CLI.dispatch(["run", @fixture])
  end

  test "dispatch run reports run_id when awaiting approval" do
    approval = Path.expand("../fixtures/approval_state.yml", __DIR__)

    assert {:error, :awaiting_approval, 2} = CLI.dispatch(["run", approval])
  end

  test "dispatch returns usage for unknown command" do
    assert :usage = CLI.dispatch(["nope"])
  end

  test "dispatch run reports missing program" do
    assert {:error, _, 1} = CLI.dispatch(["run", "/nonexistent/program.yml"])
  end

  test "dispatch run awaits approval" do
    approval = Path.expand("../fixtures/approval_state.yml", __DIR__)
    assert {:error, :awaiting_approval, 2} = CLI.dispatch(["run", approval])
  end

  test "dispatch status not_found" do
    assert {:error, :not_found, 1} = CLI.dispatch(["status", "run-missing"])
  end

  test "dispatch approve rejects invalid label" do
    approval = Path.expand("../fixtures/approval_state.yml", __DIR__)
    {:ok, run_id} = Coordinator.start(approval)
    assert {:error, :invalid_label, 1} = CLI.dispatch(["approve", run_id, "not-a-real-label"])
  end

  test "dispatch approve rejects non-approval run" do
    {:ok, run_id} = Coordinator.start(@fixture)
    assert {:error, :invalid_approve, 1} = CLI.dispatch(["approve", run_id, "done"])
  end

  test "run completes echo_ok program via main" do
    assert capture_io(fn -> CLI.main(["run", @fixture]) end) =~ "workflow finished"
  end

  test "status via dispatch succeeds for active run" do
    {:ok, run_id} = Coordinator.start(@fixture)
    assert :ok = CLI.dispatch(["status", run_id])
  end

  test "approve via CLI" do
    approval = Path.expand("../fixtures/approval_state.yml", __DIR__)
    {:ok, run_id} = Coordinator.start(approval)

    assert capture_io(fn -> CLI.main(["approve", run_id, "done"]) end) =~ "approved"
  end

  test "cancel via CLI" do
    {:ok, run_id} = Coordinator.start(@fixture)

    assert capture_io(fn -> CLI.main(["cancel", run_id]) end) =~ "cancelled"
  end

  test "mix orchestrator task delegates to CLI" do
    assert capture_io(fn -> Mix.Task.run("orchestrator", ["run", @fixture]) end) =~
             "workflow finished"
  end

  test "dispatch run reports no_orchestrator_layout" do
    tmp = System.tmp_dir!()
    path = Path.join(tmp, "standalone.yml")

    File.write!(
      path,
      "program:\n  id: x\n  version: 1\n  initial: idle\nstates: {}\nnodes: {}\n"
    )

    on_exit(fn -> File.rm(path) end)

    without_workspace_env(fn ->
      assert {:error, :no_orchestrator_layout, 1} = CLI.dispatch(["run", path])
    end)
  end

  test "dispatch run reports invalid_start" do
    minimal = Path.expand("../fixtures/minimal_passive.yml", __DIR__)
    assert {:error, :invalid_start, 1} = CLI.dispatch(["run", minimal])
  end

  describe "main" do
    test "status success prints nothing extra" do
      {:ok, run_id} = Coordinator.start(@fixture)
      assert capture_io(fn -> CLI.main(["status", run_id]) end) == ""
    end
  end

  test "approve resume without ORCHESTRATOR_WORKSPACE env" do
    approval = Path.expand("../fixtures/approval_state.yml", __DIR__)
    {:ok, run_id} = Coordinator.start(approval)

    without_workspace_env(fn ->
      assert capture_io(fn -> CLI.main(["approve", run_id, "done"]) end) =~ "approved"
    end)
  end

  defp without_workspace_env(fun) do
    prev = System.get_env("ORCHESTRATOR_WORKSPACE")
    System.delete_env("ORCHESTRATOR_WORKSPACE")

    try do
      fun.()
    after
      case prev do
        nil -> System.delete_env("ORCHESTRATOR_WORKSPACE")
        value -> System.put_env("ORCHESTRATOR_WORKSPACE", value)
      end
    end
  end

end
