defmodule Definitively.Run.CoordinatorTest do
  use ExUnit.Case, async: false

  alias Definitively.Run.Coordinator

  @fixture Path.expand("../../fixtures/echo_ok.yml", __DIR__)

  test "run_until_final completes echo_ok fixture" do
    assert :ok = Coordinator.run_until_final(@fixture)
  end

  test "start and status expose run snapshot" do
    assert {:ok, run_id} = Coordinator.start(@fixture)
    assert {:ok, snap} = Coordinator.status(run_id)
    assert snap.program_id == "echo_ok"
    refute snap.done
  end

  test "approve on approval fixture" do
    approval = Path.expand("../../fixtures/approval_state.yml", __DIR__)
    assert {:ok, run_id} = Coordinator.start(approval)
    assert :ok = Coordinator.approve(run_id, :done)
    assert {:ok, %{done: true}} = Coordinator.status(run_id)
  end

  test "cancel reaches failed final" do
    assert {:ok, run_id} = Coordinator.start(@fixture)
    assert :ok = Coordinator.cancel(run_id)
    assert {:ok, %{current_state: :failed, done: true}} = Coordinator.status(run_id)
  end

  test "status not_found" do
    assert {:error, :not_found} = Coordinator.status("run-missing")
  end

  test "step when not active" do
    approval = Path.expand("../../fixtures/approval_state.yml", __DIR__)
    assert {:ok, run_id} = Coordinator.start(approval)
    assert {:error, :not_active} = Coordinator.step(run_id)
  end

  test "run_until_final auto-approves approval-only program" do
    approval = Path.expand("../../fixtures/approval_state.yml", __DIR__)
    assert :ok = Coordinator.run_until_final(approval)
  end

  test "run_until_final auto-approves await_approval fixture" do
    path = Path.expand("../../fixtures/await_approval.yml", __DIR__)
    assert :ok = Coordinator.run_until_final(path)
  end

  test "run_until_final drives llm_step fixture" do
    llm = Path.expand("../../fixtures/llm_step.yml", __DIR__)
    assert :ok = Coordinator.run_until_final(llm)
  end

  test "start rejects missing program" do
    assert {:error, _} = Coordinator.start("/nonexistent/program.yml")
  end

  test "start fails when passive state lacks start transition" do
    minimal = Path.expand("../../fixtures/minimal_passive.yml", __DIR__)
    assert {:error, :invalid_start} = Coordinator.start(minimal)
  end

  test "step on slow node classifies timeout" do
    slow = Path.expand("../../fixtures/slow_timeout.yml", __DIR__)
    assert {:ok, run_id} = Coordinator.start(slow)
    assert :ok = Coordinator.step(run_id)
    assert {:ok, %{done: true}} = Coordinator.status(run_id)
  end

  test "run_until_final stops when approval has no auto label" do
    path = Path.expand("../../fixtures/reject_only.yml", __DIR__)
    assert {:error, :awaiting_approval} = Coordinator.run_until_final(path)
  end
end
