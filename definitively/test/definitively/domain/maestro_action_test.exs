defmodule Definitively.Domain.MaestroActionTest do
  use ExUnit.Case

  alias Definitively.Domain.{MaestroAction, NodeDefinition}
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

  test "task_claim_next uses mission_id from sealed state", %{tmp: tmp} do
    :ok = RunState.seal(tmp, %{"mission_id" => "pln-test-123"})

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
    assert RunState.get(tmp, "task_id") == "tsk-abc"
  end

  test "mission_from_spec parse failure signals parse_failed", %{tmp: tmp} do
    {signals, data} = MaestroAction.parse_result(:mission_from_spec, 0, "no mission here", tmp)

    assert signals[:parse_failed]
    assert data["error"] =~ "mission_id"
    refute RunState.get(tmp, "mission_id")
  end

  test "mission_from_spec stores and seals mission_id", %{tmp: tmp} do
    :ok = RunState.seal(tmp, %{"spec_path" => ".maestro/specs/foo.md"})

    {_signals, data} =
      MaestroAction.parse_result(:mission_from_spec, 0, "pln-test-999 approved (foo)", tmp)

    assert data["mission_id"] == "pln-test-999"
    assert RunState.get(tmp, "mission_id") == "pln-test-999"

    File.write!(RunState.path(tmp), "{}")
    assert RunState.get(tmp, "mission_id") == "pln-test-999"
  end

  test "recover_existing_mission resolves id from missions.jsonl", %{tmp: tmp} do
    missions_dir = Path.join([tmp, ".maestro", "missions"])
    File.mkdir_p!(missions_dir)

    line =
      ~s({"id":"pln-resume-1","slug":"agent-profile-refactor-054927eb","state":"approved"})

    File.write!(Path.join(missions_dir, "missions.jsonl"), line <> "\n")

    stderr =
      "maestro mission from-spec: Mission with slug agent-profile-refactor-054927eb already exists\n"

    assert {:ok, "pln-resume-1", stdout} = MaestroAction.recover_existing_mission(stderr, tmp)
    assert stdout =~ "pln-resume-1"
  end

  test "recover_existing_mission returns error for unknown slug", %{tmp: tmp} do
    assert :error =
             MaestroAction.recover_existing_mission(
               "Mission with slug missing-slug already exists",
               tmp
             )
  end

  test "recover_existing_mission ignores cancelled missions", %{tmp: tmp} do
    missions_dir = Path.join([tmp, ".maestro", "missions"])
    File.mkdir_p!(missions_dir)

    line =
      ~s({"id":"pln-cancelled","slug":"agent-profile-refactor-054927eb","state":"cancelled"})

    File.write!(Path.join(missions_dir, "missions.jsonl"), line <> "\n")

    stderr =
      "maestro mission from-spec: Mission with slug agent-profile-refactor-054927eb already exists\n"

    assert :error = MaestroAction.recover_existing_mission(stderr, tmp)
  end

  test "run_claim_next skips shipped tasks when list includes them", %{tmp: tmp} do
    list_json =
      ~s({"items":[{"id":"tsk-shipped","slug":"done","state":"shipped"},{"id":"tsk-next","slug":"wave-two","state":"draft"}],"total":2})

    runner = fn
      _exe, ["task", "list" | _], _opts ->
        {:ok, %{exit_code: 0, stdout: list_json}}

      _exe, ["task", "claim", "tsk-next"], _opts ->
        {:ok, %{exit_code: 0, stdout: "claimed"}}
    end

    assert {:ok, {0, "claimed", signals, data}} =
             MaestroAction.run_claim_next("pln-x", tmp, runner)

    assert signals[:has_tasks]
    assert data["task_id"] == "tsk-next"
  end

  test "build_argv for spec and mission actions", %{tmp: tmp} do
    spec = Path.join(tmp, ".maestro/specs/foo.md")
    File.mkdir_p!(Path.dirname(spec))
    File.write!(spec, "# spec")

    assert {:ok, ["spec", "validate", ^spec]} =
             MaestroAction.build_argv(:spec_validate, %{"spec_path" => spec}, tmp)

    assert {:ok, ["mission", "from-spec", ^spec]} =
             MaestroAction.build_argv(:mission_from_spec, %{"spec_path" => spec}, tmp)

    decompose = Path.join(tmp, "batch.json")
    File.write!(decompose, "[]")
    :ok = RunState.seal(tmp, %{"mission_id" => "pln-abc"})

    assert {:ok, ["mission", "decompose", "pln-abc", "--file", ^decompose]} =
             MaestroAction.build_argv(
               :mission_decompose,
               %{"decompose_file" => decompose},
               tmp
             )
  end

  test "spec_validate derives path from plan_file when spec_path missing", %{tmp: tmp} do
    plan = Path.join(tmp, "plans/my-feature.plan.md")
    File.mkdir_p!(Path.dirname(plan))
    File.write!(plan, "# plan")
    :ok = RunState.seal(tmp, %{"plan_file" => plan})

    expected = Path.expand(".maestro/specs/my-feature.md", tmp)

    assert {:ok, ["spec", "validate", ^expected]} =
             MaestroAction.build_argv(:spec_validate, %{}, tmp)
  end

  test "build_argv for task lifecycle actions", %{tmp: tmp} do
    :ok = RunState.seal(tmp, %{"task_id" => "tsk-1"})

    assert {:ok,
            [
              "evidence",
              "record",
              "--task",
              "tsk-1",
              "--command",
              ".maestro/bootstrap/validation/verify-gate.sh",
              "--exit",
              "0"
            ]} = MaestroAction.build_argv(:evidence_record, %{}, tmp)

    assert {:ok, ["task", "verify", "tsk-1"]} =
             MaestroAction.build_argv(:task_verify, %{}, tmp)

    assert {:ok, ["verdict", "request", "--task", "tsk-1"]} =
             MaestroAction.build_argv(:verdict_request, %{}, tmp)

    assert {:ok, ["task", "ship", "tsk-1"]} =
             MaestroAction.build_argv(:task_ship, %{}, tmp)

    assert {:ok,
            [
              "evidence",
              "record",
              "--task",
              "tsk-1",
              "--command",
              "mix test",
              "--exit",
              "1"
            ]} =
             MaestroAction.build_argv(
               :evidence_record,
               %{"command" => "mix test", "exit" => 1},
               tmp
             )
  end

  test "build_argv errors when required state is missing", %{tmp: tmp} do
    assert {:error, {:invalid_options, :mission_id, _}} =
             MaestroAction.build_argv(:task_claim_next, %{}, tmp)

    assert {:error, {:invalid_options, :spec_path, _}} =
             MaestroAction.build_argv(:spec_validate, %{}, tmp)

    assert {:error, {:unknown_action, :nope}} =
             MaestroAction.build_argv(:nope, %{}, tmp)
  end

  test "argv_for delegates to build_argv", %{tmp: tmp} do
    :ok = RunState.seal(tmp, %{"mission_id" => "pln-delegated"})

    node = %NodeDefinition{kind: :maestro, action: :task_claim_next, options: %{}}

    assert {:ok, {:claim_next, "pln-delegated"}} = MaestroAction.argv_for(node, tmp)
  end

  test "parse_result init_run loads run state", %{tmp: tmp} do
    :ok = RunState.put(tmp, %{"mission_id" => "pln-init"})

    {signals, data} = MaestroAction.parse_result(:init_run, 0, "", tmp)
    assert signals == %{}
    assert data["mission_id"] == "pln-init"
  end

  test "parse_result task_claim_next reflects sealed task_id", %{tmp: tmp} do
    :ok = RunState.seal(tmp, %{"task_id" => "tsk-live", "task_slug" => "slug-a"})

    {signals, data} = MaestroAction.parse_result(:task_claim_next, 0, "", tmp)
    assert signals[:has_tasks]
    assert data["task_id"] == "tsk-live"
    assert data["task_slug"] == "slug-a"
  end

  test "parse_result task_claim_next signals no_tasks when task_id absent", %{tmp: tmp} do
    {signals, data} = MaestroAction.parse_result(:task_claim_next, 0, "", tmp)
    assert signals[:no_tasks]
    refute data["has_tasks"]
  end

  test "parse_result generic actions decode json or trim stdout", %{tmp: tmp} do
    {_, json_data} = MaestroAction.parse_result(:task_verify, 0, ~s({"ok":true}), tmp)
    assert json_data == %{"ok" => true}

    {_, text_data} = MaestroAction.parse_result(:task_verify, 0, "  shipped\n", tmp)
    assert text_data == %{"stdout" => "shipped"}

    assert MaestroAction.parse_result(:task_verify, 1, "fail", tmp) == {%{}, %{}}
  end

  test "find_mission_id_by_slug resolves approved missions", %{tmp: tmp} do
    missions_dir = Path.join([tmp, ".maestro", "missions"])
    File.mkdir_p!(missions_dir)

    line = ~s({"id":"pln-found","slug":"my-slug","state":"planned"})
    File.write!(Path.join(missions_dir, "missions.jsonl"), line <> "\n")

    assert {:ok, "pln-found"} = MaestroAction.find_mission_id_by_slug(tmp, "my-slug")
    assert :error = MaestroAction.find_mission_id_by_slug(tmp, "missing")
  end

  test "run_claim_next handles list failure and parse errors", %{tmp: tmp} do
    fail_runner = fn _exe, _args, _opts ->
      {:ok, %{exit_code: 2, stdout: "list failed"}}
    end

    assert {:ok, {2, "list failed", %{}, %{}}} =
             MaestroAction.run_claim_next("pln-x", tmp, fail_runner)

    bad_json_runner = fn _exe, _args, _opts ->
      {:ok, %{exit_code: 0, stdout: "not-json"}}
    end

    assert {:ok, {1, "not-json", %{}, %{"error" => "failed to parse task list"}}} =
             MaestroAction.run_claim_next("pln-x", tmp, bad_json_runner)

    invalid_items_runner = fn _exe, _args, _opts ->
      {:ok, %{exit_code: 0, stdout: ~s({"items":[{"id":"tsk-x"}],"total":1})}}
    end

    assert {:ok, {1, _, %{}, %{"error" => "invalid task list JSON"}}} =
             MaestroAction.run_claim_next("pln-x", tmp, invalid_items_runner)
  end

  test "run_claim_next handles claim failure and runner error", %{tmp: tmp} do
    list_json = ~s({"items":[{"id":"tsk-fail","slug":"wave","state":"draft"}],"total":1})

    claim_fail_runner = fn
      _exe, ["task", "list" | _], _opts ->
        {:ok, %{exit_code: 0, stdout: list_json}}

      _exe, ["task", "claim", "tsk-fail"], _opts ->
        {:ok, %{exit_code: 3, stdout: "claim denied"}}
    end

    assert {:ok, {3, "claim denied", %{}, %{}}} =
             MaestroAction.run_claim_next("pln-x", tmp, claim_fail_runner)

    err_runner = fn _exe, _args, _opts -> {:error, :timeout} end
    assert {:error, :timeout} = MaestroAction.run_claim_next("pln-x", tmp, err_runner)
  end

  test "run_claim_next skips abandoned tasks", %{tmp: tmp} do
    list_json =
      ~s({"items":[{"id":"tsk-dead","slug":"old","state":"abandoned"},{"id":"tsk-live","slug":"next","state":"draft"}],"total":2})

    runner = fn
      _exe, ["task", "list" | _], _opts ->
        {:ok, %{exit_code: 0, stdout: list_json}}

      _exe, ["task", "claim", "tsk-live"], _opts ->
        {:ok, %{exit_code: 0, stdout: "claimed"}}
    end

    assert {:ok, {0, "claimed", signals, data}} =
             MaestroAction.run_claim_next("pln-x", tmp, runner)

    assert signals[:has_tasks]
    assert data["task_id"] == "tsk-live"
  end
end
