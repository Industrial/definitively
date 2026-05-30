defmodule Orchestrator.VisualizeTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Visualize

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
    assert {:dot, nil} = Visualize.parse_cli_opts([])
    assert {:png, "/tmp/x"} = Visualize.parse_cli_opts(["--format", "png", "--out", "/tmp/x"])
    assert {:svg, nil} = Visualize.parse_cli_opts(["svg"])
  end

  test "cli_render returns stdout dot" do
    assert {:ok, {:stdout, dot}} = Visualize.cli_render(@fixture, [])
    assert dot =~ "digraph"
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
end
