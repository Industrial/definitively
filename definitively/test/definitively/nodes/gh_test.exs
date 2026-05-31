defmodule Definitively.Nodes.GhTest do
  use ExUnit.Case, async: false

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Domain.RawResult
  alias Definitively.Nodes.Gh
  alias Definitively.Workflow.RunContext

  setup do
    prev = Application.get_env(:definitively, :gh_runner)
    on_exit(fn -> restore_gh_runner(prev) end)
    :ok
  end

  test "uses injectable gh_runner" do
    Application.put_env(:definitively, :gh_runner, {__MODULE__, :fake_run, []})

    node = %NodeDefinition{
      id: :pr,
      kind: :gh,
      action: :pr_create,
      options: %{"title" => "Hi"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.data["url"] =~ "pull"
  end

  test "rejects non-gh nodes" do
    node = %NodeDefinition{id: :x, kind: :git, action: :status, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:error, {:unsupported_kind, :git}} = Gh.execute(node, ctx)
  end

  def fake_run(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok,
     %RawResult{
       exit_code: 0,
       stdout: "https://github.com/o/r/pull/42\n",
       data: %{"url" => "https://github.com/o/r/pull/42", "number" => 42}
     }}
  end

  defp restore_gh_runner(nil), do: Application.delete_env(:definitively, :gh_runner)
  defp restore_gh_runner(val), do: Application.put_env(:definitively, :gh_runner, val)
end
