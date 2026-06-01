defmodule Definitively.MCPTest do
  use ExUnit.Case, async: false

  alias Definitively.MCP
  alias Definitively.MCP.Serve

  @definitively_root Path.expand("../..", __DIR__)

  @echo Path.expand("../fixtures/echo_ok.yml", __DIR__)
  @approval Path.expand("../fixtures/approval_state.yml", __DIR__)
  @await Path.expand("../fixtures/await_approval.yml", __DIR__)
  @llm Path.expand("../fixtures/llm_step.yml", __DIR__)
  @reject_only Path.expand("../fixtures/reject_only.yml", __DIR__)

  test "tools list" do
    assert MCP.tools() == ["workflow_run", "workflow_visualize"]
  end

  test "workflow_run finishes echo_ok" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @echo})
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

  test "workflow_run awaiting_approval when gate has no auto label" do
    assert {:ok, %{ok: false, awaiting_approval: true}} =
             MCP.handle_tool("workflow_run", %{"program_path" => @reject_only})
  end

  test "workflow_run accepts run_id" do
    assert {:ok, %{ok: true, result: "finished"}} =
             MCP.handle_tool("workflow_run", %{
               "program_path" => @echo,
               "run_id" => "mcp-test-run"
             })
  end

  test "workflow_visualize defaults unknown format to dot" do
    assert {:ok, %{ok: true, format: "dot", dot: dot}} =
             MCP.handle_tool("workflow_visualize", %{
               "program_path" => @echo,
               "format" => "bogus"
             })

    assert dot =~ "digraph"
  end

  @tag :graphviz
  test "workflow_visualize svg format when dot exists" do
    if System.find_executable("dot") do
      tmp = System.tmp_dir!()
      out = Path.join(tmp, "orch_mcp_viz_svg")

      assert {:ok, %{ok: true, format: "svg", path: path}} =
               MCP.handle_tool("workflow_visualize", %{
                 "program_path" => @echo,
                 "format" => "svg",
                 "out" => out
               })

      assert String.ends_with?(path, ".svg")
      File.rm(path)
    end
  end

  test "workflow_visualize fails for missing program" do
    assert {:error, %{error: %{code: :visualize_failed, message: message}}} =
             MCP.handle_tool("workflow_visualize", %{"program_path" => "/nope.yml"})

    assert is_binary(message)
    assert message != ""
  end

  describe "MCP.Serve" do
    setup do
      on_exit(fn ->
        System.delete_env("DEFINITIVELY_LOG_LEVEL")
        Logger.configure(level: :warning)
        stop_serve_supervisor()
      end)

      :ok
    end

    test "log_level_from_env maps known levels" do
      assert Serve.log_level_from_env("trace") == :debug
      assert Serve.log_level_from_env("debug") == :debug
      assert Serve.log_level_from_env("info") == :info
      assert Serve.log_level_from_env("warn") == :warning
      assert Serve.log_level_from_env("warning") == :warning
      assert Serve.log_level_from_env("error") == :error
      assert Serve.log_level_from_env("bogus") == :warning
      assert Serve.log_level_from_env("  INFO  ") == :info
    end

    test "log_level_from_env reads DEFINITIVELY_LOG_LEVEL when arg is nil" do
      System.put_env("DEFINITIVELY_LOG_LEVEL", "error")
      assert Serve.log_level_from_env() == :error
    end

    test "configure_logging! applies env level to Logger" do
      System.put_env("DEFINITIVELY_LOG_LEVEL", "error")
      assert :ok = Serve.configure_logging!()
      assert Logger.level() == :error
    end

    test "start_stdio_supervisor links stdio MCP children" do
      stop_serve_supervisor()

      assert {:ok, pid} = Serve.start_stdio_supervisor()
      assert is_pid(pid) and Process.alive?(pid)
      assert {:error, {:already_started, _}} = Serve.start_stdio_supervisor()
    end

    test "run reports failed start when supervisor name is taken" do
      expr = """
      Application.ensure_all_started(:logger)
      Application.ensure_all_started(:definitively)
      children = [
        Hermes.Server.Registry,
        {Definitively.MCPServer, transport: :stdio}
      ]
      {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one, name: Definitively.MCP.Serve.Supervisor)
      Definitively.MCP.Serve.run()
      """

      {output, status} = mix_run(expr)

      assert status != 0
      assert output =~ "failed to start"
    end

    test "run halts when supervisor stops" do
      expr = """
      Application.ensure_all_started(:logger)
      Application.ensure_all_started(:definitively)
      spawn(fn ->
        Process.sleep(500)
        case Process.whereis(Definitively.MCP.Serve.Supervisor) do
          nil -> :ok
          pid -> Supervisor.stop(pid, :normal)
        end
      end)
      Definitively.MCP.Serve.run()
      """

      {output, status} = mix_run(expr)

      assert status != 0
      assert output =~ "stopped"
    end

    test "await_supervisor returns when pid exits" do
      task =
        Task.async(fn ->
          receive do
            :stop -> :normal
          end
        end)

      parent = self()

      spawn(fn ->
        send(parent, {:reason, Serve.await_supervisor(task.pid)})
      end)

      Process.sleep(50)
      send(task.pid, :stop)
      assert_receive {:reason, :normal}, 1000
    end

    test "run_body reports failed start" do
      System.put_env("DEFINITIVELY_LOG_LEVEL", "warn")

      assert {:halt, message} =
               Serve.run_body({:error, {:already_started, self()}})

      assert message =~ "failed to start"
    end

    test "run_body reports supervisor stop" do
      task =
        Task.async(fn ->
          receive do
            :stop -> :normal
          end
        end)

      parent = self()

      spawn(fn ->
        send(parent, Serve.run_body({:ok, task.pid}))
      end)

      Process.sleep(50)
      send(task.pid, :stop)

      assert_receive {:halt, message}, 1000
      assert message =~ "stopped"
    end
  end

  defp stop_serve_supervisor do
    case Process.whereis(Definitively.MCP.Serve.Supervisor) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          try do
            Supervisor.stop(pid)
          catch
            :exit, _ -> :ok
          end
        else
          :ok
        end
    end
  end

  defp mix_run(expr) do
    System.cmd(
      "mix",
      ["run", "-e", expr],
      cd: @definitively_root,
      env: [{"MIX_ENV", "test"}],
      stderr_to_stdout: true
    )
  end
end
