defmodule Definitively.Nodes.MaestroTest do
  use ExUnit.Case

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Domain.RawResult
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

    node = %NodeDefinition{
      id: :init,
      kind: :maestro,
      action: :init_run,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, inputs: %{"plan_file" => plan}, env: %{}}

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

  test "mission_from_spec recovers existing mission from stderr", %{tmp: tmp} do
    spec = Path.join(tmp, ".maestro/specs/demo.md")
    File.mkdir_p!(Path.dirname(spec))
    File.write!(spec, "# spec")

    missions_dir = Path.join([tmp, ".maestro", "missions"])
    File.mkdir_p!(missions_dir)

    line = ~s({"id":"pln-resume-1","slug":"demo","state":"approved"})
    File.write!(Path.join(missions_dir, "missions.jsonl"), line <> "\n")

    :ok = RunState.seal(tmp, %{"spec_path" => spec})

    prev = Application.get_env(:definitively, :maestro_runner)

    Application.put_env(
      :definitively,
      :maestro_runner,
      {__MODULE__, :existing_mission_runner, []}
    )

    on_exit(fn ->
      if prev do
        Application.put_env(:definitively, :maestro_runner, prev)
      else
        Application.delete_env(:definitively, :maestro_runner)
      end
    end)

    node = %NodeDefinition{
      id: :mission_from_spec,
      kind: :maestro,
      action: :mission_from_spec,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} = Maestro.invoke(node, ctx, ["mission", "from-spec", spec], tmp, 60_000)
    assert raw.exit_code == 0
    assert RunState.get(tmp, "mission_id") == "pln-resume-1"
  end

  def existing_mission_runner(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok,
     %RawResult{
       exit_code: 1,
       stdout: "",
       stderr: "maestro mission from-spec: Mission with slug demo already exists\n"
     }}
  end
end
