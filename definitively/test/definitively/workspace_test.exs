defmodule Definitively.WorkspaceTest do
  use ExUnit.Case, async: false

  alias Definitively.Workspace

  @program Path.expand(
             "../../../.definitively/programs/dev-quality-loop.yml",
             __DIR__
           )

  test "resolve_run finds workspace from repo program path" do
    assert {:ok, %{program_path: path, workspace_root: root}} =
             Workspace.resolve_run(@program)

    assert File.regular?(path)
    assert path == Path.expand(@program)
    assert File.dir?(Path.join(root, ".definitively"))
    assert String.starts_with?(path, Path.join(root, ".definitively") <> "/")
  end

  test "resolve_run expands relative paths" do
    relative = Path.relative_to(@program, File.cwd!())

    assert {:ok, %{program_path: abs}} = Workspace.resolve_run(relative)
    assert abs == Path.expand(@program)
  end

  test "resolve_run returns enoent for missing file" do
    assert {:error, :enoent} =
             Workspace.resolve_run("/nonexistent/definitively-program.yml")
  end

  test "resolve_run returns no_definitively_layout outside tree" do
    without_workspace_env(fn ->
      tmp = Path.join(System.tmp_dir!(), "orch_ws_#{System.unique_integer()}")
      File.mkdir_p!(tmp)
      path = Path.join(tmp, "standalone.yml")

      File.write!(
        path,
        "program:\n  id: x\n  version: 1\n  initial: idle\nstates: {}\nnodes: {}\n"
      )

      on_exit(fn -> File.rm_rf(tmp) end)

      assert {:error, :no_definitively_layout} = Workspace.resolve_run(path)
    end)
  end
  test "resolve_run uses DEFINITIVELY_WORKSPACE when layout is absent" do
    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    root = Path.expand("../../..", __DIR__)
    path = Path.join(root, "tmp_workspace_env_test.yml")
    File.write!(path, "program:\n  id: x\n  version: 1\n  initial: idle\nstates: {}\nnodes: {}\n")

    on_exit(fn ->
      File.rm(path)
      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        value -> System.put_env("DEFINITIVELY_WORKSPACE", value)
      end
    end)

    System.put_env("DEFINITIVELY_WORKSPACE", root)

    assert {:ok, %{workspace_root: ^root}} = Workspace.resolve_run(path)
  end

  defp without_workspace_env(fun) do
    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.delete_env("DEFINITIVELY_WORKSPACE")

    try do
      fun.()
    after
      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        value -> System.put_env("DEFINITIVELY_WORKSPACE", value)
      end
    end
  end
end
