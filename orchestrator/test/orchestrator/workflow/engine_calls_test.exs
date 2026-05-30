defmodule Orchestrator.Workflow.EngineCallsTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Outcome
  alias Orchestrator.Spec.Loader
  alias Orchestrator.Workflow.Engine

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)
  @approval Path.expand("../../fixtures/approval_state.yml", __DIR__)

  defp start!(path) do
    {:ok, program} = Loader.load(path)
    :gen_statem.start(Engine, [program: program], [])
  end

  test "invalid start on active state" do
    {:ok, pid} = start!(@fixture)
    assert :ok = :gen_statem.call(pid, {:start, :default})
    assert {:error, :invalid_start} = :gen_statem.call(pid, {:start, :default})
    :ok = :gen_statem.stop(pid)
  end

  test "node_result on passive state returns not_active" do
    {:ok, pid} = start!(@fixture)

    assert {:error, :not_active} =
             :gen_statem.call(pid, {:node_result, Outcome.success()})

    :ok = :gen_statem.stop(pid)
  end

  test "invalid approve on non-approval state" do
    {:ok, pid} = start!(@fixture)
    assert :ok = :gen_statem.call(pid, {:start, :default})

    assert {:error, :invalid_approve} = :gen_statem.call(pid, {:approve, :done})

    :ok = :gen_statem.stop(pid)
  end

  test "noop before final returns not_final" do
    {:ok, pid} = start!(@fixture)
    assert {:error, :not_final} = :gen_statem.call(pid, :noop)
    :ok = :gen_statem.stop(pid)
  end

  test "status returns snapshot" do
    {:ok, pid} = start!(@approval)

    assert %{program_id: "bad", state_type: :approval, approval_prompt: nil} =
             :gen_statem.call(pid, :status)

    :ok = :gen_statem.stop(pid)
  end

  test "cancel without failed state returns cannot_cancel" do
    {:ok, pid} = start!(@approval)
    assert {:error, :cannot_cancel} = :gen_statem.call(pid, :cancel)
    :ok = :gen_statem.stop(pid)
  end
end
