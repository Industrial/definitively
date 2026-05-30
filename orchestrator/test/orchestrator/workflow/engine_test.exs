defmodule Orchestrator.Workflow.EngineTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Spec.Loader
  alias Orchestrator.Workflow.Engine

  @approval_fixture Path.expand("../../fixtures/approval_state.yml", __DIR__)

  test "approval state transitions on approve label" do
    {:ok, program} = Loader.load(@approval_fixture)
    {:ok, pid} = :gen_statem.start(Engine, [program: program], [])

    assert :ok = :gen_statem.call(pid, {:approve, :done})
    assert :finished = :gen_statem.call(pid, :noop)

    :ok = :gen_statem.stop(pid)
  end

  test "load_default_program! returns dev_quality_loop" do
    program = Engine.load_default_program!()
    assert program.id == "dev_quality_loop"
    assert program.initial == :idle
  end

  test "cancel moves to failed when present in program" do
    program = Engine.load_default_program!()
    {:ok, pid} = :gen_statem.start(Engine, [program: program], [])

    assert :ok = :gen_statem.call(pid, {:start, :default})
    assert :ok = :gen_statem.call(pid, :cancel)
    assert :failed = :gen_statem.call(pid, :noop)

    :ok = :gen_statem.stop(pid)
  end
end
