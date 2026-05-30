defmodule Orchestrator.MCPTest do
  use ExUnit.Case, async: false

  alias Orchestrator.MCP
  alias Orchestrator.Run.Coordinator

  @echo Path.expand("../fixtures/echo_ok.yml", __DIR__)
  @approval Path.expand("../fixtures/approval_state.yml", __DIR__)
  @await Path.expand("../fixtures/await_approval.yml", __DIR__)
  @llm Path.expand("../fixtures/llm_step.yml", __DIR__)

  test "tools list" do
    assert "workflow_run" in MCP.tools()
    assert "workflow_approve" in MCP.tools()
  end

  test "workflow_run auto_run finishes echo_ok" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @echo})
  end

  test "workflow_run without auto_run returns run_id" do
    assert {:ok, %{ok: true, run_id: run_id}} =
             MCP.handle_tool("workflow_run", %{
               "program_path" => @echo,
               "auto_run" => false
             })

    assert is_binary(run_id)
  end

  test "workflow_status returns snapshot fields" do
    {:ok, run_id} = Coordinator.start(@echo)

    assert {:ok, %{run_id: ^run_id, program_id: "echo_ok", done: false}} =
             MCP.handle_tool("workflow_status", %{"run_id" => run_id})
  end

  test "workflow_run stops at approval" do
    assert {:ok, %{ok: false, awaiting_approval: true}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @approval})
  end

  test "workflow_approve drives to final" do
    {:ok, run_id} = Coordinator.start(@await)

    assert {:ok, %{ok: true, run_id: ^run_id}} =
             MCP.handle_tool("workflow_approve", %{"run_id" => run_id, "label" => "approve"})

    assert {:ok, %{done: true}} = Coordinator.status(run_id)
  end

  test "workflow_cancel" do
    {:ok, run_id} = Coordinator.start(@echo)

    assert {:ok, %{ok: true, run_id: ^run_id}} =
             MCP.handle_tool("workflow_cancel", %{"run_id" => run_id})
  end

  test "workflow_run llm fixture completes" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @llm})
  end

  test "unknown tool" do
    assert {:error, %{error: %{code: :unknown_tool}}} =
             MCP.handle_tool("nope", %{})
  end

  test "invalid params" do
    assert {:error, %{error: %{code: :invalid_params}}} = MCP.handle_tool("workflow_run", %{})
    assert {:error, %{error: %{code: :invalid_params}}} = MCP.handle_tool("workflow_status", %{})
    assert {:error, %{error: %{code: :invalid_params}}} = MCP.handle_tool("workflow_approve", %{})
    assert {:error, %{error: %{code: :invalid_params}}} = MCP.handle_tool("workflow_cancel", %{})
  end

  test "workflow_status not_found" do
    assert {:error, %{error: %{code: :status_failed}}} =
             MCP.handle_tool("workflow_status", %{"run_id" => "run-missing"})
  end

  test "workflow_run start_failed" do
    assert {:error, %{error: %{code: :start_failed}}} =
             MCP.handle_tool("workflow_run", %{"program_path" => "/nope.yml", "auto_run" => false})
  end

  test "workflow_approve invalid label" do
    {:ok, run_id} = Coordinator.start(@approval)

    assert {:error, %{error: %{code: :approve_failed}}} =
             MCP.handle_tool("workflow_approve", %{"run_id" => run_id, "label" => "nope"})
  end

  test "await_approval exposes prompt in status" do
    {:ok, run_id} = Coordinator.start(@await)

    assert {:ok, %{approval_prompt: "Ship this change?", state_type: :approval}} =
             MCP.handle_tool("workflow_status", %{"run_id" => run_id})
  end
end
