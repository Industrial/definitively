defmodule Definitively.VisualizeTest do
  use ExUnit.Case, async: false

  alias Definitively.Visualize

  @fixture Path.expand("../fixtures/echo_ok.yml", __DIR__)

  test "to_dot includes states and transitions" do
    assert {:ok, dot} = Visualize.to_dot(@fixture)
    assert dot =~ "digraph"
    assert dot =~ "idle"
    assert dot =~ "run"
    assert dot =~ "done"
    assert dot =~ "start"
  end

  test "build produces graph for echo_ok" do
    assert {:ok, graph} = Visualize.graph(@fixture)
    assert is_map(graph)
  end

  test "render dot format" do
    assert {:ok, dot} = Visualize.render(@fixture, format: :dot)
    assert is_binary(dot)
  end

  test "render rejects unknown format" do
    assert {:error, {:invalid_format, :bogus}} =
             Visualize.render(@fixture, format: :bogus)
  end

  test "render png strips extension from --out path" do
    if System.find_executable("dot") do
      tmp = System.tmp_dir!()
      out = Path.join(tmp, "orch_viz_ext.png")

      assert {:ok, file} = Visualize.render(@fixture, format: :png, out: out)
      assert file == Path.rootname(out) <> ".png"
      File.rm(file)
    end
  end

  test "parse_cli_opts" do
    assert {:default, nil, nil} = Visualize.parse_cli_opts([])

    assert {:single, :png, "/tmp/x"} =
             Visualize.parse_cli_opts(["--format", "png", "--out", "/tmp/x"])

    assert {:single, :svg, nil} = Visualize.parse_cli_opts(["svg"])
    assert {:single, :dot, "ignored"} = Visualize.parse_cli_opts(["--out", "ignored"])
  end

  test "cli_render default writes dot and png to workspace visualizations dir" do
    with_workspace_program(@fixture, fn program, workspace ->
      viz_dir = Path.join([workspace, ".definitively", "visualizations"])
      dot_path = Path.join(viz_dir, "echo_ok.dot")
      png_path = Path.join(viz_dir, "echo_ok.png")

      if System.find_executable("dot") do
        assert {:ok, {:files, paths}} = Visualize.cli_render(program, [])
        assert paths == [dot_path, png_path]
        assert File.regular?(dot_path)
        assert File.read!(dot_path) =~ "digraph"
        assert File.regular?(png_path)
      else
        assert {:error, {:graphviz_unavailable, _, [dot_path: ^dot_path]}} =
                 Visualize.cli_render(program, [])

        assert File.regular?(dot_path)
        refute File.exists?(png_path)
      end
    end)
  end

  test "cli_render single format writes to default visualizations dir" do
    with_workspace_program(@fixture, fn program, workspace ->
      dot_path = Path.join([workspace, ".definitively", "visualizations", "echo_ok.dot"])

      assert {:ok, {:files, [^dot_path]}} =
               Visualize.cli_render(program, ["--format", "dot"])

      assert File.read!(dot_path) =~ "digraph"
    end)
  end

  test "cli_render single format with out override" do
    with_workspace_program(@fixture, fn program, _workspace ->
      tmp = System.tmp_dir!()
      out = Path.join(tmp, "orch_viz_cli_out")
      dot_path = out <> ".dot"

      assert {:ok, {:files, [^dot_path]}} =
               Visualize.cli_render(program, ["--format", "dot", "--out", out])

      assert File.read!(dot_path) =~ "digraph"
      File.rm(dot_path)
    end)
  end

  @tag :graphviz
  test "render png when dot is available" do
    if System.find_executable("dot") do
      tmp = System.tmp_dir!()
      out = Path.join(tmp, "orch_viz_test")
      on_exit(fn -> File.rm(out <> ".png") end)

      assert {:ok, file} = Visualize.render(@fixture, format: :png, out: out)
      assert String.ends_with?(file, ".png")
      assert File.regular?(file)
    end
  end

  defp with_workspace_program(fixture, fun) do
    tmp = Path.join(System.tmp_dir!(), "orch_viz_ws_#{System.unique_integer()}")
    programs = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(programs)
    program = Path.join(programs, Path.basename(fixture))
    File.cp!(fixture, program)

    prev = System.get_env("DEFINITIVELY_WORKSPACE")
    System.put_env("DEFINITIVELY_WORKSPACE", tmp)

    on_exit(fn ->
      File.rm_rf(tmp)

      case prev do
        nil -> System.delete_env("DEFINITIVELY_WORKSPACE")
        v -> System.put_env("DEFINITIVELY_WORKSPACE", v)
      end
    end)

    fun.(program, tmp)
  end
end
