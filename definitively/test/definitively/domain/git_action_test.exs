defmodule Definitively.Domain.GitActionTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.{GitAction, NodeDefinition}

  test "status builds porcelain argv" do
    assert {:ok, ["status", "--porcelain=v1", "-b"]} = GitAction.build_argv(:status, %{})
  end

  test "diff builds argv with optional flags" do
    assert {:ok, ["diff"]} = GitAction.build_argv(:diff, %{})
    assert {:ok, ["diff", "--staged", "--stat"]} = GitAction.build_argv(:diff, %{"staged" => "1", "stat" => true})
  end

  test "add all builds git add -A" do
    assert {:ok, ["add", "-A"]} = GitAction.build_argv(:add, %{"all" => true})
    assert {:ok, ["add", "-A"]} = GitAction.build_argv(:add, %{"all" => "all"})
  end

  test "add with paths" do
    assert {:ok, ["add", "a.ex", "b.ex"]} = GitAction.build_argv(:add, %{"paths" => ["a.ex", "b.ex"]})
  end

  test "add validation errors" do
    assert {:error, {:invalid_options, :add, _}} = GitAction.build_argv(:add, %{})
    assert {:error, {:invalid_options, :add, _}} = GitAction.build_argv(:add, %{"paths" => []})
    assert {:error, {:invalid_options, :add, _}} = GitAction.build_argv(:add, %{"paths" => "file.ex"})
  end

  test "commit requires message" do
    assert {:error, {:invalid_options, :commit, _}} = GitAction.build_argv(:commit, %{})
  end

  test "commit with add all returns multi argv" do
    assert {:ok, {:multi, [add, commit]}} =
             GitAction.build_argv(:commit, %{"message" => "hi", "add" => "all"})

    assert add == ["add", "-A"]
    assert commit == ["commit", "-m", "hi"]
  end

  test "commit with paths add and flags" do
    assert {:ok, {:multi, [["add", "x.ex"], commit]}} =
             GitAction.build_argv(:commit, %{"message" => "hi", "add" => ["x.ex"]})

    assert commit == ["commit", "-m", "hi"]

    assert {:ok, commit_only} =
             GitAction.build_argv(:commit, %{
               "message" => "hi",
               "add" => "not-a-list",
               "amend" => true,
               "allow_empty" => "true"
             })

    assert commit_only == ["commit", "-m", "hi", "--amend", "--allow-empty"]
  end

  test "push builds argv with upstream and tags" do
    assert {:ok, ["push", "origin", "main"]} =
             GitAction.build_argv(:push, %{"branch" => "main"})

    assert {:ok, ["push", "--set-upstream", "upstream", "dev", "--tags"]} =
             GitAction.build_argv(:push, %{
               "remote" => "upstream",
               "branch" => "dev",
               "set_upstream" => true,
               "tags" => 1
             })
  end

  test "tag builds create and optional push" do
    assert {:ok, ["tag", "v1.0.0"]} = GitAction.build_argv(:tag, %{"name" => "v1.0.0"})

    assert {:ok, ["tag", "-a", "v2.0.0", "-m", "release"]} =
             GitAction.build_argv(:tag, %{"name" => "v2.0.0", "annotate" => true, "message" => "release"})

    assert {:ok, {:multi, [create, push]}} =
             GitAction.build_argv(:tag, %{"name" => "v3.0.0", "push" => true, "remote" => "origin"})

    assert create == ["tag", "v3.0.0"]
    assert push == ["push", "origin", "v3.0.0"]
  end

  test "tag requires name" do
    assert {:error, {:invalid_options, :tag, _}} = GitAction.build_argv(:tag, %{})
  end

  test "unknown action returns error" do
    assert {:error, {:unknown_action, :nope}} = GitAction.build_argv(:nope, %{})
  end

  test "argv_for delegates to build_argv" do
    node = %NodeDefinition{kind: :git, action: :status, options: %{}}
    assert {:ok, ["status", "--porcelain=v1", "-b"]} = GitAction.argv_for(node)
  end

  test "parse_result status sets clean signal" do
    stdout = "## main\n"
    {signals, data} = GitAction.parse_result(:status, 0, stdout)
    assert signals[:clean]
    assert data["clean"]
    refute signals[:dirty]
    assert data["branch"] == "## main"
  end

  test "parse_result status sets dirty signal" do
    stdout = "## main\n M file.txt\n"
    {signals, _data} = GitAction.parse_result(:status, 0, stdout)
    assert signals[:dirty]
    refute signals[:clean]
  end

  test "parse_result status sets ahead and behind signals" do
    {ahead, _} = GitAction.parse_result(:status, 0, "## main...origin/main [ahead 2]\n")
    {behind, _} = GitAction.parse_result(:status, 0, "## main...origin/main [behind 1]\n")
    assert ahead[:ahead]
    assert behind[:behind]
  end

  test "parse_result status handles empty output" do
    {signals, data} = GitAction.parse_result(:status, 0, "")
    assert signals[:clean]
    assert data["branch"] == ""
  end

  test "parse_result diff" do
    {signals, data} = GitAction.parse_result(:diff, 0, " file.ex | 1 +\n")
    assert signals[:has_changes]
    assert data["has_changes"]

    {signals, data} = GitAction.parse_result(:diff, 0, "   \n")
    refute signals[:has_changes]
    refute data["has_changes"]

    assert GitAction.parse_result(:diff, 1, "err") == {%{}, %{}}
    assert GitAction.parse_result(:commit, 0, "") == {%{}, %{}}
  end
end
