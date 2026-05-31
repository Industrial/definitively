defmodule Definitively.Spec.LoaderGitGhTest do
  use ExUnit.Case, async: true

  alias Definitively.Spec.Loader

  @fixture Path.expand("../../fixtures/git_gh_ship.yml", __DIR__)

  test "loads git_gh_ship fixture" do
    assert {:ok, program} = Loader.load(@fixture)
    assert program.id == "git_gh_ship"
    assert Map.has_key?(program.nodes, :repo_status)
    assert program.nodes.repo_status.kind == :git
    assert program.nodes.repo_status.action == :status
    assert program.nodes.watch_ci.kind == :gh
    assert program.nodes.watch_ci.action == :run_watch
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
end
