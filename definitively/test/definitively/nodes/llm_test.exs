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

  test "agent profile drives execution and parses json output" do
    prev_runner = Application.get_env(:definitively, :llm_runner)
    Application.put_env(:definitively, :llm_runner, nil)
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

    fixtures = Path.expand("../../fixtures", __DIR__)

    node = %NodeDefinition{
      kind: :llm,
      agent: :stub,
      prompt_file: "prompts/test.md"
    }

    ctx = %RunContext{run_id: "t", workspace_root: fixtures, env: %{}}

    assert {:ok, %RawResult{llm_json: %{"status" => "ok"}, signals: %{"fix_complete" => true}}} =
             Llm.execute(node, ctx)
  end

  test "stream_stub profile parses stream_json output" do
    prev_runner = Application.get_env(:definitively, :llm_runner)
    Application.put_env(:definitively, :llm_runner, nil)
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

    fixtures = Path.expand("../../fixtures", __DIR__)

    node = %NodeDefinition{
      kind: :llm,
      agent: :stream_stub,
      prompt_file: "prompts/test.md"
    }

    ctx = %RunContext{run_id: "t", workspace_root: fixtures, env: %{}}

    assert {:ok, %RawResult{llm_json: %{"status" => "ok"}, signals: %{"fix_complete" => true}}} =
             Llm.execute(node, ctx)
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

    test "parses cursor stream-json result line with string payload" do
      line =
        ~s({"type":"result","subtype":"success","result":"{\"status\":\"ok\",\"signals\":{\"fix_complete\":true}}"})

      System.put_env("DEFINITIVELY_LLM_COMMAND", "printf " <> ~s('%s') <> " " <> line)
      node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file, model: "m"}
      root = @workspace_root
      ctx = %RunContext{run_id: "t", workspace_root: root, env: %{}}

      assert {:ok, %RawResult{llm_json: %{"status" => "ok"}, signals: %{"fix_complete" => true}}} =
               Llm.execute(node, ctx)

      assert Llm.stream_complete?(line)
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
  test "resolve agent id from run inputs" do
    prev_runner = Application.get_env(:definitively, :llm_runner)
    Application.put_env(:definitively, :llm_runner, nil)
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

    fixtures = Path.expand("../../fixtures", __DIR__)

    node = %NodeDefinition{
      kind: :llm,
      agent: nil,
      prompt_file: "prompts/test.md"
    }

    ctx = %RunContext{
      run_id: "t",
      workspace_root: fixtures,
      env: %{},
      inputs: %{"agent" => "stub"}
    }

    assert {:ok, %RawResult{llm_json: %{"status" => "ok"}}} = Llm.execute(node, ctx)
  end

  test "resolve agent id from DEFINITIVELY_AGENT env" do
    prev_runner = Application.get_env(:definitively, :llm_runner)
    prev_agent = System.get_env("DEFINITIVELY_AGENT")
    Application.put_env(:definitively, :llm_runner, nil)
    System.put_env("DEFINITIVELY_AGENT", "stub")

    on_exit(fn ->
      Application.put_env(:definitively, :llm_runner, prev_runner)

      case prev_agent do
        nil -> System.delete_env("DEFINITIVELY_AGENT")
        v -> System.put_env("DEFINITIVELY_AGENT", v)
      end
    end)

    fixtures = Path.expand("../../fixtures", __DIR__)
    node = %NodeDefinition{kind: :llm, prompt_file: "prompts/test.md"}
    ctx = %RunContext{run_id: "t", workspace_root: fixtures, env: %{}}

    assert {:ok, %RawResult{llm_json: %{"status" => "ok"}}} = Llm.execute(node, ctx)
  end

  test "enrich_raw ignores non-map signals in json envelope" do
    prev_runner = Application.get_env(:definitively, :llm_runner)

    Application.put_env(:definitively, :llm_runner, {__MODULE__, :bad_signals_runner, []})
    on_exit(fn -> Application.put_env(:definitively, :llm_runner, prev_runner) end)

    node = %NodeDefinition{kind: :llm, prompt_file: @prompt_file}
    ctx = %RunContext{run_id: "t", workspace_root: @workspace_root, env: %{}}

    assert {:ok, %RawResult{signals: signals}} = Llm.execute(node, ctx)
    assert is_map(signals)
  end

  def bad_signals_runner(_node, _ctx, _prompt) do
    {:ok,
     %RawResult{
       exit_code: 0,
       stdout: "",
       duration_ms: 1,
       llm_json: %{"status" => "ok", "signals" => "nope"},
       signals: %{}
     }}
  end

end
