defmodule Definitively.MCPTest do
  use ExUnit.Case, async: false

  alias Definitively.MCP

  @echo Path.expand("../fixtures/echo_ok.yml", __DIR__)
  @approval Path.expand("../fixtures/approval_state.yml", __DIR__)
  @await Path.expand("../fixtures/await_approval.yml", __DIR__)
  @llm Path.expand("../fixtures/llm_step.yml", __DIR__)

  test "tools list" do
    assert MCP.tools() == ["workflow_run", "workflow_visualize"]
  end

  test "workflow_run finishes echo_ok" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @echo})
  end

  test "workflow_run returns log_path" do
    with_tmp_workspace_program(@echo, fn program, workspace ->
      assert {:ok, %{ok: true, result: "finished", log_path: log_path}} =
               MCP.handle_tool("workflow_run", %{
                 "program_path" => program,
                 "workspace_root" => workspace
               })

      assert String.starts_with?(log_path, Path.join([workspace, ".definitively", "logs"]))
      assert log_path =~ "-echo_ok.log"
      assert File.regular?(log_path)
    end)
  end

  test "workflow_run auto-approves approval programs" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @approval})
  end

  test "workflow_run finishes await_approval" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @await})
  end

  test "workflow_visualize returns dot" do
    assert {:ok, %{ok: true, format: "dot", dot: dot}} =
             MCP.handle_tool("workflow_visualize", %{"program_path" => @echo})

    assert dot =~ "digraph"
  end

  @tag :graphviz
  test "workflow_visualize png format when dot exists" do
    if System.find_executable("dot") do
      tmp = System.tmp_dir!()
      out = Path.join(tmp, "orch_mcp_viz")

      assert {:ok, %{ok: true, format: "png", path: path}} =
               MCP.handle_tool("workflow_visualize", %{
                 "program_path" => @echo,
                 "format" => "png",
                 "out" => out
               })

      assert String.ends_with?(path, ".png")
      File.rm(path)
    end
  end

  test "workflow_run llm fixture completes" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @llm})
  end

  test "unknown tool" do
    assert {:error, %{error: %{code: :unknown_tool}}} =
             MCP.handle_tool("nope", %{})
  end

  test "invalid params" do
    assert {:error, %{error: %{code: :invalid_params}}} = MCP.handle_tool("workflow_run", %{})

    assert {:error, %{error: %{code: :invalid_params}}} =
             MCP.handle_tool("workflow_visualize", %{})
  end

  test "workflow_run accepts workspace_root" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{
               "program_path" => @echo,
               "workspace_root" => File.cwd!()
             })
  end

  defp with_tmp_workspace_program(fixture, fun) do
    tmp = Path.join(System.tmp_dir!(), "orch_mcp_ws_#{System.unique_integer()}")
    programs = Path.join([tmp, ".definitively", "programs"])
    File.mkdir_p!(programs)
    program = Path.join(programs, Path.basename(fixture))
    File.cp!(fixture, program)
    on_exit(fn -> File.rm_rf(tmp) end)
    fun.(program, tmp)
  end

  test "workflow_run start_failed for missing file" do
    assert {:error, %{error: %{code: :run_failed}}} =
             MCP.handle_tool("workflow_run", %{"program_path" => "/nope.yml"})
  end
end
