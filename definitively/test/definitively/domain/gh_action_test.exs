defmodule Definitively.Domain.GhActionTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.{GhAction, NodeDefinition}

  test "pr_create requires title" do
    assert {:error, {:invalid_options, :pr_create, _}} = GhAction.build_argv(:pr_create, %{})
    assert {:error, {:invalid_options, :pr_create, _}} = GhAction.build_argv(:pr_create, %{"title" => ""})
  end

  test "pr_create builds argv with optional flags" do
    assert {:ok, args} =
             GhAction.build_argv(:pr_create, %{
               "title" => "Hi",
               "body" => "Details",
               "base" => "main",
               "head" => "feature",
               "draft" => "true"
             })

    assert args == [
             "pr",
             "create",
             "--title",
             "Hi",
             "--body",
             "Details",
             "--base",
             "main",
             "--head",
             "feature",
             "--draft"
           ]
  end

  test "pr_create accepts atom keys" do
    assert {:ok, ["pr", "create", "--title", "Hi"]} =
             GhAction.build_argv(:pr_create, %{title: "Hi"})
  end

  test "pr_view requires number or branch" do
    assert {:error, {:invalid_options, :pr_view, _}} = GhAction.build_argv(:pr_view, %{})
  end

  test "pr_view builds argv by number or branch" do
    fields = "number,state,title,url,headRefName,baseRefName"

    assert {:ok, ["pr", "view", "42", "--json", ^fields]} =
             GhAction.build_argv(:pr_view, %{"number" => 42})

    assert {:ok, ["pr", "view", "feature-x", "--json", ^fields]} =
             GhAction.build_argv(:pr_view, %{branch: "feature-x"})
  end

  test "run_list builds argv with defaults and filters" do
    fields = "databaseId,status,conclusion,workflowName,headBranch,url"

    assert {:ok, ["run", "list", "--limit", "5", "--json", ^fields]} =
             GhAction.build_argv(:run_list, %{})

    assert {:ok, ["run", "list", "--limit", "10", "--json", ^fields, "--workflow", "ci.yml", "--branch", "main"]} =
             GhAction.build_argv(:run_list, %{"limit" => 10, "workflow" => "ci.yml", "branch" => "main"})
  end

  test "run_watch with workflow resolves then watches" do
    assert {:ok, {:resolve_then_watch, list_args}} =
             GhAction.build_argv(:run_watch, %{"workflow" => "ci.yml", "branch" => "main"})

    assert list_args == [
             "run",
             "list",
             "--workflow",
             "ci.yml",
             "--limit",
             "1",
             "--json",
             "databaseId",
             "--branch",
             "main"
           ]
  end

  test "run_watch with run_id watches directly" do
    assert {:ok, ["run", "watch", "99", "--exit-status"]} =
             GhAction.build_argv(:run_watch, %{"run_id" => 99})
  end

  test "run_watch requires run_id or workflow" do
    assert {:error, {:invalid_options, :run_watch, _}} = GhAction.build_argv(:run_watch, %{})
  end

  test "run_view builds single or multi argv" do
    fields = "databaseId,status,conclusion,workflowName,url,headBranch"

    assert {:ok, ["run", "view", "7", "--json", ^fields]} =
             GhAction.build_argv(:run_view, %{"run_id" => 7})

    assert {:ok, {:multi, [view, log]}} =
             GhAction.build_argv(:run_view, %{"run_id" => 7, "log_failed" => true})

    assert view == ["run", "view", "7", "--json", fields]
    assert log == ["run", "view", "7", "--log-failed"]
  end

  test "run_view requires run_id" do
    assert {:error, {:invalid_options, :run_view, _}} = GhAction.build_argv(:run_view, %{})
  end

  test "unknown action returns error" do
    assert {:error, {:unknown_action, :nope}} = GhAction.build_argv(:nope, %{})
  end

  test "argv_for delegates to build_argv" do
    node = %NodeDefinition{kind: :gh, action: :pr_create, options: %{"title" => "T"}}

    assert {:ok, ["pr", "create", "--title", "T"]} = GhAction.argv_for(node)
  end

  test "extract_run_id from json array" do
    assert {:ok, "12345"} = GhAction.extract_run_id(~s([{"databaseId":12345}]))
    assert {:ok, "99"} = GhAction.extract_run_id(~s([99]))
    assert {:error, :no_run_found} = GhAction.extract_run_id("[]")
    assert {:error, :no_run_found} = GhAction.extract_run_id("not json")
  end

  test "parse_result pr_create extracts url and number" do
    {signals, data} = GhAction.parse_result(:pr_create, 0, "https://github.com/o/r/pull/42\n")
    assert signals == %{}
    assert data["url"] =~ "/pull/42"
    assert data["number"] == 42
  end

  test "parse_result pr_view sets state signals" do
    for {state, signal} <- [{"OPEN", :open}, {"MERGED", :merged}, {"CLOSED", :closed}] do
      json = ~s({"state":"#{state}","number":1})
      {signals, data} = GhAction.parse_result(:pr_view, 0, json)
      assert signals[signal]
      assert data["state"] == state
    end

    {signals, data} = GhAction.parse_result(:pr_view, 0, "bad json")
    assert signals == %{}
    assert data == nil
  end

  test "parse_result run_list and run_view" do
    list_json = ~s([{"databaseId":1}])
    {_, list_data} = GhAction.parse_result(:run_list, 0, list_json)
    assert list_data["runs"] == [%{"databaseId" => 1}]

    view_json = ~s({"conclusion":"success","status":"completed"})
    {view_signals, view_data} = GhAction.parse_result(:run_view, 0, view_json)
    assert view_signals[:success]
    assert view_data["conclusion"] == "success"

    assert GhAction.parse_result(:run_list, 0, "x") == {%{}, nil}
    assert GhAction.parse_result(:run_view, 0, "x") == {%{}, nil}
    assert GhAction.parse_result(:other, 1, "") == {%{}, nil}
  end
end
