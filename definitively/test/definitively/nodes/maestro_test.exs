defmodule Definitively.Nodes.MaestroTest do
  use ExUnit.Case, async: false

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Domain.RawResult
  alias Definitively.Maestro.RunState
  alias Definitively.Nodes.Maestro
  alias Definitively.Workflow.RunContext

  setup do
    tmp = Path.join(System.tmp_dir!(), "def-maestro-node-#{System.unique_integer()}")
    File.mkdir_p!(Path.join(tmp, ".definitively/state"))
    prev_path = System.get_env("PATH")
    prev_runner = Application.get_env(:definitively, :maestro_runner)

    on_exit(fn ->
      File.rm_rf!(tmp)

      if prev_path do
        System.put_env("PATH", prev_path)
      else
        System.delete_env("PATH")
      end

      if prev_runner do
        Application.put_env(:definitively, :maestro_runner, prev_runner)
      else
        Application.delete_env(:definitively, :maestro_runner)
      end
    end)

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

  test "init_run fails without plan file", %{tmp: tmp} do
    for key <- ["DEFINITIVELY_PLAN_FILE", "DEFINITIVELY_PLAN"] do
      prev = System.get_env(key)
      System.delete_env(key)
      on_exit(fn -> if prev, do: System.put_env(key, prev), else: System.delete_env(key) end)
    end

    node = %NodeDefinition{id: :init, kind: :maestro, action: :init_run, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: tmp, inputs: %{}, env: %{}}

    assert {:error, {:missing_plan_file, _}} = Maestro.execute(node, ctx)
  end

  test "invoke passes through non-raw runner results" do
    with_runner(:error_runner)

    node = %NodeDefinition{id: :x, kind: :maestro, action: :task_verify, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}

    assert {:error, :boom} =
             Maestro.invoke(node, ctx, ["task", "verify", "tsk-1"], ".", 60_000)
  end

  test "invoke with empty argv returns empty success", %{tmp: tmp} do
    node = %NodeDefinition{id: :noop, kind: :maestro, action: :task_verify, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} = Maestro.invoke(node, ctx, [], tmp, 60_000)
    assert raw.exit_code == 0
    assert raw.stdout == ""
  end

  test "task_claim_next claims first draft task", %{tmp: tmp} do
    workspace_with_fake_maestro(tmp, claim_next_script())
    :ok = RunState.seal(tmp, %{"mission_id" => "pln-demo"})

    node = %NodeDefinition{
      id: :claim,
      kind: :maestro,
      action: :task_claim_next,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Maestro.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.signals[:has_tasks]
    assert RunState.get(tmp, "task_id") == "tsk-1"
  end

  test "maestro argv command finalizes stdout", %{tmp: tmp} do
    workspace_with_fake_maestro(tmp, verify_script())

    node = %NodeDefinition{
      id: :verify,
      kind: :maestro,
      action: :task_verify,
      options: %{"task_id" => "tsk-1"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Maestro.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.data["status"] == "ok"
  end

  test "maestro argv command returns timed_out raw", %{tmp: tmp} do
    workspace_with_fake_maestro(tmp, slow_maestro_script())

    node = %NodeDefinition{
      id: :verify,
      kind: :maestro,
      action: :task_verify,
      options: %{"task_id" => "tsk-1"},
      timeout_ms: 50,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Maestro.execute(node, ctx)
    assert raw.timed_out
  end

  test "mission_from_spec keeps failure when recovery misses", %{tmp: tmp} do
    spec = Path.join(tmp, ".maestro/specs/demo.md")
    File.mkdir_p!(Path.dirname(spec))
    File.write!(spec, "# spec")

    with_runner(:missing_mission_runner)

    node = %NodeDefinition{
      id: :mission_from_spec,
      kind: :maestro,
      action: :mission_from_spec,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} =
             Maestro.invoke(node, ctx, ["mission", "from-spec", spec], tmp, 60_000)

    assert raw.exit_code == 1
  end

  test "mission_decompose recovers when mission already decomposed", %{tmp: tmp} do
    with_runner(:already_decomposed_runner)

    node = %NodeDefinition{
      id: :decompose,
      kind: :maestro,
      action: :mission_decompose,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} =
             Maestro.invoke(node, ctx, ["mission", "decompose", "pln-1"], tmp, 60_000)

    assert raw.exit_code == 0
    assert raw.stdout =~ "Invalid mission transition in-progress -> planned"
  end

  test "finalize uses stdout for non-recoverable actions", %{tmp: tmp} do
    with_runner(:verify_runner)

    node = %NodeDefinition{
      id: :verify,
      kind: :maestro,
      action: :task_verify,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} =
             Maestro.invoke(node, ctx, ["task", "verify", "tsk-1"], tmp, 60_000)

    assert raw.exit_code == 0
    assert raw.data["status"] == "ok"
  end

  test "mission_decompose keeps failure without recovery", %{tmp: tmp} do
    with_runner(:decompose_failure_runner)

    node = %NodeDefinition{
      id: :decompose,
      kind: :maestro,
      action: :mission_decompose,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} =
             Maestro.invoke(node, ctx, ["mission", "decompose", "pln-1"], tmp, 60_000)

    assert raw.exit_code == 1
  end

  test "parse_failed forces exit code 1", %{tmp: tmp} do
    spec = Path.join(tmp, ".maestro/specs/demo.md")
    File.mkdir_p!(Path.dirname(spec))
    File.write!(spec, "# spec")
    :ok = RunState.seal(tmp, %{"spec_path" => spec})

    with_runner(:unparseable_mission_runner)

    node = %NodeDefinition{
      id: :mission_from_spec,
      kind: :maestro,
      action: :mission_from_spec,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}

    assert {:ok, raw} =
             Maestro.invoke(node, ctx, ["mission", "from-spec", spec], tmp, 60_000)

    assert raw.exit_code == 1
    assert raw.signals[:parse_failed]
  end

  def error_runner(_node, _ctx, _argv, _cwd, _timeout), do: {:error, :boom}

  def missing_mission_runner(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok,
     %RawResult{
       exit_code: 1,
       stdout: "",
       stderr: "maestro mission from-spec: Mission with slug demo already exists\n"
     }}
  end

  def decompose_failure_runner(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok, %RawResult{exit_code: 1, stdout: "", stderr: "unexpected failure\n"}}
  end

  def already_decomposed_runner(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok,
     %RawResult{
       exit_code: 1,
       stdout: "",
       stderr: "Invalid mission transition in-progress -> planned\n"
     }}
  end

  def verify_runner(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok, %RawResult{exit_code: 0, stdout: ~s({"status":"ok"})}}
  end

  def unparseable_mission_runner(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok, %RawResult{exit_code: 0, stdout: "created mission without id\n"}}
  end

  defp with_runner(fun) do
    prev = Application.get_env(:definitively, :maestro_runner)
    Application.put_env(:definitively, :maestro_runner, {__MODULE__, fun, []})

    on_exit(fn ->
      if prev do
        Application.put_env(:definitively, :maestro_runner, prev)
      else
        Application.delete_env(:definitively, :maestro_runner)
      end
    end)
  end

  defp workspace_with_fake_maestro(tmp, script) do
    bin = Path.join(tmp, "bin")
    File.mkdir_p!(bin)
    exe = Path.join(bin, "maestro")
    File.write!(exe, script)
    File.chmod!(exe, 0o755)
    prev = System.get_env("PATH") || ""
    System.put_env("PATH", bin <> ":" <> prev)
    Application.delete_env(:definitively, :maestro_runner)
  end

  defp claim_next_script do
    """
    #!/bin/sh
    case "$1 $2" in
      "task list")
        echo '{"items":[{"id":"tsk-1","slug":"demo","state":"draft"}]}'
        ;;
      "task claim")
        echo claimed
        ;;
    esac
    """
  end

  defp verify_script do
    ~s(#!/bin/sh\necho '{"status":"ok"}'\n)
  end

  defp slow_list_maestro_script do
    "#!/bin/sh\ncase \"$1 $2\" in \"task list\") sleep 60 ;; esac\n"
  end

  defp slow_maestro_script do
    "#!/bin/sh\nsleep 60\n"
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
