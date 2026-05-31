defmodule Definitively.Domain.MaestroActionTest do
  use ExUnit.Case

  alias Definitively.Domain.MaestroAction
  alias Definitively.Maestro.RunState

  setup do
    tmp = Path.join(System.tmp_dir!(), "def-maestro-#{System.unique_integer()}")
    File.mkdir_p!(Path.join(tmp, ".definitively/state"))
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  test "init_run path derives spec and decompose paths", %{tmp: tmp} do
    plan = Path.join(tmp, "plans/foo.plan.md")
    File.mkdir_p!(Path.dirname(plan))
    File.write!(plan, "# plan")

    assert :ok = RunState.init_plan(tmp, %{"plan_file" => plan})
    assert {:ok, :init_run} = MaestroAction.build_argv(:init_run, %{}, tmp)
  end

  test "task_claim_next uses mission_id from state", %{tmp: tmp} do
    :ok = RunState.put(tmp, %{"mission_id" => "pln-test-123"})

    assert {:ok, {:claim_next, "pln-test-123"}} =
             MaestroAction.build_argv(:task_claim_next, %{}, tmp)
  end

  test "run_claim_next with empty list sets no_tasks", %{tmp: tmp} do
    runner = fn _exe, _args, _opts ->
      {:ok, %{exit_code: 0, stdout: ~s({"items":[],"total":0})}}
    end

    assert {:ok, {0, "", signals, data}} =
             MaestroAction.run_claim_next("pln-x", tmp, runner)

    assert signals[:no_tasks]
    refute data["has_tasks"]
  end

  test "run_claim_next claims first draft task", %{tmp: tmp} do
    list_json = ~s({"items":[{"id":"tsk-abc","slug":"wave-one"}],"total":1})

    runner = fn
      _exe, ["task", "list" | _], _opts ->
        {:ok, %{exit_code: 0, stdout: list_json}}

      _exe, ["task", "claim", "tsk-abc"], _opts ->
        {:ok, %{exit_code: 0, stdout: "claimed"}}
    end

    assert {:ok, {0, "claimed", signals, data}} =
             MaestroAction.run_claim_next("pln-x", tmp, runner)

    assert signals[:has_tasks]
    assert data["task_id"] == "tsk-abc"
    assert RunState.load(tmp)["task_id"] == "tsk-abc"
  end
end
