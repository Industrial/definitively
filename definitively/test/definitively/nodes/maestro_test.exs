defmodule Definitively.Nodes.MaestroTest do
  use ExUnit.Case

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Maestro.RunState
  alias Definitively.Nodes.Maestro
  alias Definitively.Workflow.RunContext

  setup do
    tmp = Path.join(System.tmp_dir!(), "def-maestro-node-#{System.unique_integer()}")
    File.mkdir_p!(Path.join(tmp, ".definitively/state"))
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  test "init_run records plan and spec paths", %{tmp: tmp} do
    plan = Path.join(tmp, ".cursor/plans/demo.plan.md")
    File.mkdir_p!(Path.dirname(plan))
    File.write!(plan, "# demo")

    node = %NodeDefinition{id: :init, kind: :maestro, action: :init_run, options: %{"plan_file" => plan}, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} = Maestro.execute(node, ctx)
    assert raw.exit_code == 0

    state = RunState.load(tmp)
    assert state["plan_file"] == plan
    assert state["spec_path"] == ".maestro/specs/demo.md"
    assert RunState.get(tmp, "plan_file") == plan
    assert RunState.load_sealed(tmp)["spec_path"] == ".maestro/specs/demo.md"
  end

  test "rejects non-maestro nodes" do
    node = %NodeDefinition{id: :x, kind: :cli, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:error, {:unsupported_kind, :cli}} = Maestro.execute(node, ctx)
  end
end
