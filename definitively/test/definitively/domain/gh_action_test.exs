defmodule Definitively.Domain.GhActionTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.GhAction

  test "pr_create requires title" do
    assert {:error, {:invalid_options, :pr_create, _}} = GhAction.build_argv(:pr_create, %{})
  end

  test "pr_create builds argv" do
    assert {:ok, args} = GhAction.build_argv(:pr_create, %{"title" => "Hi"})
    assert args == ["pr", "create", "--title", "Hi"]
  end

  test "run_watch with workflow resolves then watches" do
    assert {:ok, {:resolve_then_watch, list_args}} =
             GhAction.build_argv(:run_watch, %{"workflow" => "ci.yml"})

    assert "run" in list_args
    assert "ci.yml" in list_args
  end

  test "run_watch with run_id watches directly" do
    assert {:ok, ["run", "watch", "99", "--exit-status"]} =
             GhAction.build_argv(:run_watch, %{"run_id" => 99})
  end

  test "extract_run_id from json array" do
    assert {:ok, "12345"} = GhAction.extract_run_id(~s([{"databaseId":12345}]))
  end

  test "parse_result pr_view sets open signal" do
    json = ~s({"state":"OPEN","number":1})
    {signals, data} = GhAction.parse_result(:pr_view, 0, json)
    assert signals[:open]
    assert data["state"] == "OPEN"
  end
end
