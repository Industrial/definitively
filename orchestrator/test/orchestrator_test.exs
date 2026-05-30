defmodule OrchestratorTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Outcome
  alias Orchestrator.Workflow.Engine

  test "lint/fix/commit happy path via gen_statem" do
    {:ok, pid} = :gen_statem.start(Engine, [], [])

    assert :ok = :gen_statem.call(pid, {:start, :default})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.failure()})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    assert :finished = :gen_statem.call(pid, :noop)

    :ok = :gen_statem.stop(pid)
  end

  test "run_demo walks the default workflow" do
    assert :ok = Orchestrator.run_demo()
  end
end
