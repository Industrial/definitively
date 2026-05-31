defmodule Definitively.Domain.GitActionTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.GitAction

  test "status builds porcelain argv" do
    assert {:ok, ["status", "--porcelain=v1", "-b"]} = GitAction.build_argv(:status, %{})
  end

  test "add all builds git add -A" do
    assert {:ok, ["add", "-A"]} = GitAction.build_argv(:add, %{"all" => true})
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

  test "parse_result status sets clean signal" do
    stdout = "## main\n"
    {signals, data} = GitAction.parse_result(:status, 0, stdout)
    assert signals[:clean]
    assert data["clean"]
    refute signals[:dirty]
  end

  test "parse_result status sets dirty signal" do
    stdout = "## main\n M file.txt\n"
    {signals, _data} = GitAction.parse_result(:status, 0, stdout)
    assert signals[:dirty]
    refute signals[:clean]
  end
end
