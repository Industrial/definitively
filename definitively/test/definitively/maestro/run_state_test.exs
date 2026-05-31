defmodule Definitively.Maestro.RunStateTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Definitively.Maestro.RunState

  setup do
    tmp = Path.join(System.tmp_dir!(), "def-run-state-#{System.unique_integer()}")
    File.mkdir_p!(Path.join(tmp, ".definitively/state"))
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  test "sealed keys survive working state clobber", %{tmp: tmp} do
    :ok = RunState.put(tmp, %{"plan_file" => "/tmp/plan.md"})
    :ok = RunState.seal(tmp, %{"mission_id" => "pln-abc-123", "plan_file" => "/tmp/plan.md"})

    File.write!(RunState.path(tmp), ~s({"decompose_file": ".definitively/state/x.json"}))

    assert RunState.get(tmp, "mission_id") == "pln-abc-123"
    assert RunState.get(tmp, "plan_file") == "/tmp/plan.md"
    assert RunState.get(tmp, "decompose_file") == ".definitively/state/x.json"
  end

  test "put does not clear sealed keys with nil", %{tmp: tmp} do
    :ok = RunState.seal(tmp, %{"mission_id" => "pln-keep-me"})
    :ok = RunState.put(tmp, %{"mission_id" => nil, "task_id" => "tsk-1"})

    assert RunState.get(tmp, "mission_id") == "pln-keep-me"
    assert RunState.get(tmp, "task_id") == "tsk-1"
  end

  test "init_plan reads run inputs first", %{tmp: tmp} do
    plan = Path.join(tmp, "from-input.plan.md")
    File.write!(plan, "# plan")

    assert :ok = RunState.init_plan(tmp, %{"inputs" => %{"plan_file" => plan}})
    assert RunState.get(tmp, "plan_file") == plan
  end

  test "init_plan warns on deprecated env var", %{tmp: tmp} do
    plan = Path.join(tmp, "from-env.plan.md")
    File.write!(plan, "# plan")

    prev = System.get_env("DEFINITIVELY_PLAN_FILE")
    System.put_env("DEFINITIVELY_PLAN_FILE", plan)

    on_exit(fn ->
      case prev do
        nil -> System.delete_env("DEFINITIVELY_PLAN_FILE")
        v -> System.put_env("DEFINITIVELY_PLAN_FILE", v)
      end
    end)

    log =
      capture_log(fn ->
        assert :ok = RunState.init_plan(tmp, %{})
      end)

    assert log =~ "deprecated"
    assert RunState.get(tmp, "plan_file") == plan
  end
end
