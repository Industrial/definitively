defmodule Definitively.Spec.LoaderGitGhTest do
  use ExUnit.Case, async: true

  alias Definitively.Spec.Loader

  @fixture Path.expand("../../fixtures/git_gh_ship.yml", __DIR__)
  @pre_commit_fixture Path.expand("../../fixtures/pre_commit_gate.yml", __DIR__)
  @pre_push_fixture Path.expand("../../fixtures/pre_push_gate.yml", __DIR__)
  @plan_mission_fixture Path.expand("../../fixtures/plan_mission.yml", __DIR__)

  test "loads git_gh_ship fixture" do
    assert {:ok, program} = Loader.load(@fixture)
    assert program.id == "git_gh_ship"
    assert Map.has_key?(program.nodes, :repo_status)
    assert program.nodes.repo_status.kind == :git
    assert program.nodes.repo_status.action == :status
    assert program.nodes.watch_ci.kind == :gh
    assert program.nodes.watch_ci.action == :run_watch
  end

  test "loads plan_mission fixture with maestro nodes" do
    assert {:ok, program} = Loader.load(@plan_mission_fixture)
    assert program.id == "plan_mission"
    assert program.nodes.maestro_init.kind == :maestro
    assert program.nodes.maestro_init.action == :init_run
  end

  test "loads pre_commit_gate fixture" do
    assert {:ok, program} = Loader.load(@pre_commit_fixture)
    assert program.id == "pre_commit_gate"
    assert program.states[:done].type == :final
  end

  test "loads pre_push_gate fixture" do
    assert {:ok, program} = Loader.load(@pre_push_fixture)
    assert program.id == "pre_push_gate"
    assert Map.has_key?(program.nodes, :moon_book)
  end

  test "rejects unknown git action" do
    yaml = """
    program:
      id: bad
      version: 1
      initial: idle
    states:
      idle:
        type: passive
        on:
          start: done
      done:
        type: final
    nodes:
      bad_git:
        kind: git
        action: fly
        outcome:
          success:
            - exit_code: 0
    """

    path = Path.join(System.tmp_dir!(), "bad-git-#{System.unique_integer()}.yml")
    File.write!(path, yaml)

    try do
      assert {:error, %{reason: :invalid_git_action}} = Loader.load(path)
    after
      File.rm!(path)
    end
  end

  test "rejects unknown maestro action" do
    yaml = """
    program:
      id: bad
      version: 1
      initial: idle
    states:
      idle:
        type: passive
        on:
          start: done
      done:
        type: final
    nodes:
      bad_maestro:
        kind: maestro
        action: fly
        outcome:
          success:
            - exit_code: 0
    """

    path = Path.join(System.tmp_dir!(), "bad-maestro-#{System.unique_integer()}.yml")
    File.write!(path, yaml)

    try do
      assert {:error, %{reason: :invalid_maestro_action}} = Loader.load(path)
    after
      File.rm!(path)
    end
  end
end
