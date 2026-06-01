defmodule Definitively.Run.CoordinatorTest do

defmodule FailExecutor do
  @behaviour Definitively.Nodes.Executor

  @impl true
  def execute(_node, _ctx), do: {:error, :executor_failed}
end

defmodule RetryExecutor do
  @behaviour Definitively.Nodes.Executor
  @impl true
  def execute(_node, _ctx), do: {:ok, %Definitively.Domain.RawResult{exit_code: 1}}
end

defmodule UnknownOutcomeExecutor do
  @behaviour Definitively.Nodes.Executor

  @impl true
  def execute(_node, _ctx), do: {:ok, %Definitively.Domain.RawResult{exit_code: 99}}
end

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

  test "run_until_final drives llm_step fixture via agent profile" do
    llm = Path.expand("../../fixtures/llm_step.yml", __DIR__)
    prev_runner = Application.get_env(:definitively, :llm_runner)
    Application.put_env(:definitively, :llm_runner, nil)
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

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

  test "resume continues an in-flight run" do
    assert {:ok, run_id} = Coordinator.start(@fixture)
    assert :ok = Coordinator.resume(run_id)
    assert {:ok, %{done: true}} = Coordinator.status(run_id)
  end

  test "step returns executor errors" do
    assert {:ok, run_id} = Coordinator.start(@fixture)
    assert {:error, :executor_failed} =
             Coordinator.step(run_id, executor: FailExecutor)
  end

  test "step returns engine errors for unknown outcomes" do
    assert {:ok, run_id} = Coordinator.start(@fixture)

    assert {:error, :unknown_outcome} =
             Coordinator.step(run_id,
               executor: UnknownOutcomeExecutor
             )
  end

  test "start uses DEFINITIVELY_WORKSPACE when set" do
    tmp = Path.join(System.tmp_dir!(), "def-coord-ws-#{System.unique_integer()}")
    programs = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(programs)
    program = Path.join(programs, "echo_ok.yml")
    File.cp!(@fixture, program)

    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.put_env("DEFINITIVELY_WORKSPACE", tmp)

    on_exit(fn ->
      File.rm_rf(tmp)

      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        v -> System.put_env("DEFINITIVELY_WORKSPACE", v)
      end
    end)

    assert {:ok, run_id} = Coordinator.start(program)
    assert {:ok, snap} = Coordinator.status(run_id)
    assert snap.run_context.workspace_root == tmp
  end

  test "start rejects duplicate run_id" do
    run_id = "run-dup-#{System.unique_integer()}"
    assert {:ok, ^run_id} = Coordinator.start(@fixture, run_id: run_id)
    assert {:error, {:already_started, _}} = Coordinator.start(@fixture, run_id: run_id)
  end

  test "resume returns not_found for missing run" do
    assert {:error, :not_found} = Coordinator.resume("run-missing")
  end

  test "run_until_final returns stuck for passive state without transitions" do
    path = Path.join(System.tmp_dir!(), "passive_stuck_#{System.unique_integer()}.yml")
    File.write!(path, passive_stuck_yaml())
    on_exit(fn -> File.rm(path) end)
    assert {:error, :stuck} = Coordinator.run_until_final(path)
  end

  test "run_until_final auto-approves first non-reject label" do
    path = Path.join(System.tmp_dir!(), "ship_only_#{System.unique_integer()}.yml")
    File.write!(path, ship_only_yaml())
    on_exit(fn -> File.rm(path) end)
    assert :ok = Coordinator.run_until_final(path)
  end

  defp passive_stuck_yaml do
    """
    program:
      id: passive_stuck
      version: 1
      initial: idle
    states:
      idle:
        type: passive
        on:
          start: waiting
      waiting:
        type: passive
        on:
          noop: done
      done:
        type: final
    nodes: {}
    """
  end

  test "step retry drives run_until_final on transient failure" do
    retry_yaml = Path.join(System.tmp_dir!(), "retry_#{System.unique_integer()}.yml")

    File.write!(retry_yaml, """
    program:
      id: retry_once
      version: 1
      initial: run
    states:
      run:
        type: active
        node: cmd
        on:
          success: done
          retry: run
      done:
        type: final
    nodes:
      cmd:
        kind: cli
        command: ["true"]
        outcome:
          success:
            - exit_code: 0
          retry:
            - exit_code: 1
    """)

    on_exit(fn -> File.rm(retry_yaml) end)

    assert {:ok, run_id} = Coordinator.start(retry_yaml)
    assert :retry = Coordinator.step(run_id, executor: RetryExecutor)
    assert :ok = Coordinator.step(run_id)
    assert {:ok, %{done: true}} = Coordinator.status(run_id)
  end

  test "start defaults workspace_root to cwd" do
    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.delete_env("DEFINITIVELY_WORKSPACE")
    on_exit(fn ->
      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        v -> System.put_env("DEFINITIVELY_WORKSPACE", v)
      end
    end)

    assert {:ok, run_id} = Coordinator.start(@fixture)
    assert {:ok, snap} = Coordinator.status(run_id)
    assert snap.run_context.workspace_root == File.cwd!()
  end

  defp ship_only_yaml do
    """
    program:
      id: ship_only
      version: 1
      initial: gate
    states:
      gate:
        type: approval
        on:
          ship: done
          reject: failed
      done:
        type: final
      failed:
        type: final
    nodes: {}
    """
  end
end
