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

  test "child_spec describes a temporary worker" do
    spec = Engine.child_spec([])

    assert spec.id == Engine
    assert spec.restart == :temporary
    assert {Engine, :start_link, [[]]} = spec.start
  end

  test "linting rejects unknown outcomes" do
    {:ok, pid} = :gen_statem.start(Engine, [], [])

    assert :ok = :gen_statem.call(pid, {:start, :default})

    assert {:error, :unknown_outcome} =
             :gen_statem.call(pid, {:node_result, %Outcome{status: :partial}})

    :ok = :gen_statem.stop(pid)
  end

  test "fixing retries until fix succeeds" do
    {:ok, pid} = :gen_statem.start(Engine, [], [])

    assert :ok = :gen_statem.call(pid, {:start, :default})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.failure()})
    assert :retry = :gen_statem.call(pid, {:node_result, Outcome.failure()})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    assert :finished = :gen_statem.call(pid, :noop)

    :ok = :gen_statem.stop(pid)
  end

  test "committing rejects failed node results" do
    {:ok, pid} = :gen_statem.start(Engine, [], [])

    assert :ok = :gen_statem.call(pid, {:start, :default})
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})

    assert {:error, :commit_failed} =
             :gen_statem.call(pid, {:node_result, Outcome.failure()})

    :ok = :gen_statem.stop(pid)
  end

  test "unexpected casts are ignored in each state" do
    {:ok, pid} = :gen_statem.start(Engine, [], [])

    :gen_statem.cast(pid, :noise)
    assert :ok = :gen_statem.call(pid, {:start, :default})

    :gen_statem.cast(pid, :noise)
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.failure()})

    :gen_statem.cast(pid, :noise)
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})

    :gen_statem.cast(pid, :noise)
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})

    :gen_statem.cast(pid, :noise)
    assert :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})

    :gen_statem.cast(pid, :noise)
    assert :finished = :gen_statem.call(pid, :noop)

    :gen_statem.cast(pid, :noise)
    :ok = :gen_statem.stop(pid)
  end
end
