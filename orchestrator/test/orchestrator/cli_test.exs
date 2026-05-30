defmodule Orchestrator.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Orchestrator.CLI
  alias Orchestrator.Run.Coordinator

  @fixture Path.expand("../fixtures/echo_ok.yml", __DIR__)

  test "dispatch run completes echo_ok program" do
    assert :ok = CLI.dispatch(["run", @fixture])
  end

  test "dispatch returns usage for unknown command" do
    assert :usage = CLI.dispatch(["nope"])
  end

  test "dispatch run reports missing program" do
    assert {:error, _, 1} = CLI.dispatch(["run", "/nonexistent/program.yml"])
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

end
