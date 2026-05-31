defmodule Definitively.Nodes.LlmTest do
  use ExUnit.Case, async: false

  alias Definitively.Domain.{NodeDefinition, RawResult}
  alias Definitively.Nodes.Llm
  alias Definitively.Spec.Loader
  alias Definitively.Workflow.RunContext

  @fixture Path.expand("../../fixtures/llm_step.yml", __DIR__)
  @workspace_root Path.expand("../../../..", __DIR__)
  @prompt_file "definitively/prompts/test.md"

  test "stub runner returns ok JSON envelope" do
    {:ok, program} = Loader.load(@fixture)
    node = program.nodes[:agent]
    ctx = %RunContext{run_id: "t1", workspace_root: @workspace_root, env: %{}}

    assert {:ok, %RawResult{llm_json: %{"status" => "ok"}, signals: %{"fix_complete" => true}}} =
             Llm.execute(node, ctx)
  end

  test "stub module run/3 returns configured envelope" do
    alias Definitively.Nodes.Llm.Stub

    node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file}
    ctx = %RunContext{run_id: "t1", workspace_root: @workspace_root, env: %{}}

    assert {:ok, %RawResult{signals: %{"fix_complete" => true}}} =
             Stub.run(node, ctx, "prompt body")
  end

  test "node command appends prompt after --" do
    prev_runner = Application.get_env(:definitively, :llm_runner)
    Application.put_env(:definitively, :llm_runner, nil)
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

    node = %NodeDefinition{
      kind: :llm,
      prompt_file: @prompt_file,
      command: ["echo", "--"]
    }

    root = @workspace_root
    ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

    assert {:ok, %RawResult{stdout: stdout, llm_json: %{"status" => "ok"}}} =
             Llm.execute(node, ctx)

    assert stdout =~ "Fix the issue"
  end

  test "cursor-agent resolves to DEFINITIVELY_CURSOR_AGENT or nix default" do
    assert Llm.resolve_executable("cursor-agent") == "/run/current-system/sw/bin/cursor-agent"

    System.put_env("DEFINITIVELY_CURSOR_AGENT", "/custom/cursor-agent")
    on_exit(fn -> System.delete_env("DEFINITIVELY_CURSOR_AGENT") end)
    assert Llm.resolve_executable("cursor-agent") == "/custom/cursor-agent"
    assert Llm.resolve_executable("/other/bin") == "/other/bin"
  end

  test "rejects non-llm kind" do
    node = %NodeDefinition{kind: :cli, command: "true"}

    assert {:error, {:unsupported_kind, :cli}} =
             Llm.execute(node, %RunContext{run_id: "t", workspace_root: ".", env: %{}})
  end

  test "read_prompt resolves under workspace" do
    node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file}
    root = @workspace_root

    assert {:ok, body} =
             Llm.read_prompt(node, %RunContext{workspace_root: root, run_id: "t", env: %{}})

    assert body =~ "Fix the issue"
  end

  describe "command runner" do
    setup do
      prev_runner = Application.get_env(:definitively, :llm_runner)
      prev_llm_command = System.get_env("DEFINITIVELY_LLM_COMMAND")
      Application.put_env(:definitively, :llm_runner, nil)
      System.delete_env("DEFINITIVELY_LLM_COMMAND")

      on_exit(fn ->
        Application.put_env(:definitively, :llm_runner, prev_runner)

        case prev_llm_command do
          nil -> System.delete_env("DEFINITIVELY_LLM_COMMAND")
          val -> System.put_env("DEFINITIVELY_LLM_COMMAND", val)
        end
      end)

      :ok
    end

    test "missing prompt_file" do
      node = %NodeDefinition{kind: :llm, prompt_file: nil}
      ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
      assert {:error, :missing_prompt_file} = Llm.execute(node, ctx)
    end

    test "prompt read failure" do
      node = %NodeDefinition{kind: :llm, prompt_file: "missing/prompt.md"}
      ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}

      assert {:error, {:prompt_read_failed, :enoent}} = Llm.execute(node, ctx)
    end

    test "parses JSON from DEFINITIVELY_LLM_COMMAND" do
      System.put_env("DEFINITIVELY_LLM_COMMAND", ~S|echo {"status":"ok"}|)
      node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file, model: "m"}
      root = @workspace_root
      ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

      assert {:ok, %RawResult{llm_json: %{"status" => "ok"}}} = Llm.execute(node, ctx)
    end

    test "non-json stdout gets fallback envelope" do
      System.put_env("DEFINITIVELY_LLM_COMMAND", "printf plain")
      node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file, model: "m"}
      root = @workspace_root
      ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

      assert {:ok, %RawResult{llm_json: %{"status" => "ok", "raw" => "plain"}}} =
               Llm.execute(node, ctx)
    end

    test "non-zero exit code" do
      System.put_env("DEFINITIVELY_LLM_COMMAND", "false")
      node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file, model: "m", timeout_ms: 5_000}
      root = @workspace_root
      ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

      assert {:ok, %RawResult{exit_code: 1}} = Llm.execute(node, ctx)
    end

    test "times out" do
      System.put_env("DEFINITIVELY_LLM_COMMAND", "sleep 2")
      node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file, model: "m", timeout_ms: 50}
      root = @workspace_root
      ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

      assert {:ok, %RawResult{timed_out: true, duration_ms: ms}} = Llm.execute(node, ctx)
      assert ms >= 50 and ms < 500
    end

    test "default command returns quickly without blocking on stdin" do
      node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file, model: "m", timeout_ms: 5_000}
      root = @workspace_root
      ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

      assert {:ok, %RawResult{llm_json: %{"status" => "ok"}}} = Llm.execute(node, ctx)
    end
  end
  test "stream_complete? detects ok envelope inside stream-json assistant chunks" do
    stream =
      ~s({"type":"assistant","message":{"content":[{"type":"text","text":"{\"status\":\"ok\",\"signals\":{\"fix_complete\":true}}"}]}}\n)

    assert Llm.stream_complete?(stream)
  end

  test "parses ok envelope embedded in stream-json assistant output" do
    prev_runner = Application.get_env(:definitively, :llm_runner)

    stream =
      ~s({"type":"assistant","message":{"content":[{"type":"text","text":"{\"status\":\"ok\",\"signals\":{\"fix_complete\":true}}"}]}}\n)

    Application.put_env(:definitively, :llm_runner, {__MODULE__, :stream_ok_runner, [stream]})
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

    node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file}
    ctx = %RunContext{run_id: "t", workspace_root: @workspace_root, env: %{}}

    assert {:ok, %RawResult{llm_json: %{"status" => "ok"}, signals: %{"fix_complete" => true}}} =
             Llm.execute(node, ctx)
  end

  def stream_ok_runner(_node, _ctx, _prompt, stream) do
    {:ok,
     %RawResult{
       exit_code: 0,
       stdout: stream,
       duration_ms: 1,
       timed_out: false,
       llm_json: %{"status" => "ok", "signals" => %{"fix_complete" => true}},
       signals: %{"fix_complete" => true}
     }}
  end

end
