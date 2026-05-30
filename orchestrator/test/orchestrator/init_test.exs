defmodule Orchestrator.InitTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Orchestrator.{CLI, Init}

  setup do
    tmp = Path.join(System.tmp_dir!(), "orch_init_" <> Integer.to_string(System.unique_integer()))
    File.mkdir_p!(tmp)
    prev = System.get_env("ORCHESTRATOR_WORKSPACE")
    System.put_env("ORCHESTRATOR_WORKSPACE", tmp)

    on_exit(fn ->
      File.rm_rf(tmp)

      case prev do
        nil -> System.delete_env("ORCHESTRATOR_WORKSPACE")
        v -> System.put_env("ORCHESTRATOR_WORKSPACE", v)
      end
    end)

    {:ok, workspace: tmp}
  end

  test "run copies template files into .orchestrator", %{workspace: workspace} do
    assert {:ok, %{created: created, skipped: []}} = Init.run(workspace_root: workspace)
    assert created != []

    program = Path.join([workspace, ".orchestrator", "programs", "example.yml"])
    env = Path.join([workspace, ".orchestrator", "env.example"])
    prompt = Path.join([workspace, ".orchestrator", "prompts", "example.md"])
    gitkeep = Path.join([workspace, ".orchestrator", "visualizations", ".gitkeep"])

    assert File.regular?(program)
    assert File.regular?(env)
    assert File.regular?(prompt)
    assert File.regular?(gitkeep)
    assert File.read!(program) =~ "id: example"
  end

  test "run skips existing files without force", %{workspace: workspace} do
    assert {:ok, %{created: first, skipped: []}} = Init.run(workspace_root: workspace)
    assert {:ok, %{created: [], skipped: skipped}} = Init.run(workspace_root: workspace)
    assert length(skipped) == length(first)
  end

  test "run overwrites existing files with force", %{workspace: workspace} do
    assert {:ok, %{created: first, skipped: []}} = Init.run(workspace_root: workspace)
    program = Path.join([workspace, ".orchestrator", "programs", "example.yml"])
    File.write!(program, "stale
")

    assert {:ok, %{created: second, skipped: []}} = Init.run(workspace_root: workspace, force: true)
    assert length(second) == length(first)
    assert File.read!(program) =~ "id: example"
    refute File.read!(program) =~ "stale"
  end

  test "run uses ORCHESTRATOR_WORKSPACE from env", %{workspace: workspace} do
    assert {:ok, %{created: created}} = Init.run()
    assert Enum.any?(created, &String.starts_with?(&1, workspace <> "/"))
  end

  test "dispatch init scaffolds workspace", %{workspace: workspace} do
    output = capture_io(fn -> assert :ok = CLI.dispatch(["init"]) end)

    assert output =~ "orchestrator workspace initialized"
    assert File.regular?(Path.join([workspace, ".orchestrator", "programs", "example.yml"]))
  end

  test "dispatch init accepts --force", %{workspace: workspace} do
    assert :ok = CLI.dispatch(["init"])
    program = Path.join([workspace, ".orchestrator", "programs", "example.yml"])
    File.write!(program, "stale
")

    output = capture_io(fn -> assert :ok = CLI.dispatch(["init", "--force"]) end)

    assert output =~ "created"
    assert File.read!(program) =~ "id: example"
  end

end
