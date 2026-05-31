defmodule Definitively.Maestro.RunStateTest do
  use ExUnit.Case

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
end
