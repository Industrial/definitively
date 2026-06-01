defmodule Definitively.AgentProfile.OutputParserTest do
  use ExUnit.Case, async: true

  alias Definitively.AgentProfile.OutputParser
  alias Definitively.Domain.AgentProfile

  test "parses whole stdout json" do
    config = %{format: :json, extract: :whole_stdout, envelope_path: nil, success_status: "ok"}

    assert {:ok, %{"status" => "ok"}} =
             OutputParser.parse(~s({"status":"ok"}), config)
  end

  test "parses text format as raw envelope" do
    config = %{format: :text, extract: :whole_stdout, envelope_path: nil, success_status: "ok"}

    assert {:ok, %{"status" => "ok", "raw" => "plain output"}} =
             OutputParser.parse("plain output", config)
  end

  test "parses stream_json result envelope" do
    config = AgentProfile.legacy_output()
    line = ~s({"type":"result","result":{"status":"ok","signals":{"fix_complete":true}}})

    assert {:ok, %{"status" => "ok", "signals" => %{"fix_complete" => true}}} =
             OutputParser.parse(line, config)
  end

  test "stream_complete? detects ok status" do
    config = AgentProfile.legacy_output()
    assert OutputParser.stream_complete?(~s({"status":"ok"}), config)
    refute OutputParser.stream_complete?(~s({"status":"fail"}), config)
  end

  test "parse accepts AgentProfile struct" do
    profile = %AgentProfile{
      id: :stub,
      executable: "sh",
      output: %{format: :json, extract: :whole_stdout, envelope_path: nil, success_status: "ok"}
    }

    assert {:ok, %{"status" => "ok"}} = OutputParser.parse(~s({"status":"ok"}), profile)
  end

  test "parse returns error for invalid json" do
    config = %{format: :json, extract: :whole_stdout, envelope_path: nil, success_status: "ok"}
    assert :error = OutputParser.parse("not json", config)
  end

  test "parse stream_json last_json_line from trailing status line" do
    config = %{format: :stream_json, extract: :last_json_line, envelope_path: nil, success_status: "ok"}

    output = """
    log line
    {"status":"ok","signals":{"fix_complete":true}}
    """

    assert {:ok, %{"status" => "ok"}} = OutputParser.parse(output, config)
  end

  test "parse stream_json unwraps envelope path from json string" do
    config = %{format: :stream_json, extract: :last_json_line, envelope_path: "payload", success_status: "ok"}
    inner = ~s({"status":"ok"})
    line = Jason.encode!(%{"payload" => inner})

    assert {:ok, %{"status" => "ok"}} = OutputParser.parse(line, config)
  end

  test "stream_complete? falls back to ok envelope markers in stream" do
    config = AgentProfile.legacy_output()
    noisy = ~s(chunk\n{"status":"ok","signals":{"fix_complete":true}})

    assert OutputParser.stream_complete?(noisy, config)
  end

  test "stream_complete? uses AgentProfile success_status" do
    profile = %AgentProfile{
      id: :stub,
      executable: "sh",
      output: %{format: :json, extract: :whole_stdout, envelope_path: nil, success_status: "done"}
    }

    assert OutputParser.stream_complete?(~s({"status":"done"}), profile)
    refute OutputParser.stream_complete?(~s({"status":"ok"}), profile)
  end

  test "parse stream_json unwraps envelope map payload" do
    config = %{format: :stream_json, extract: :last_json_line, envelope_path: "payload", success_status: "ok"}
    line = Jason.encode!(%{"payload" => %{"status" => "ok"}})

    assert {:ok, %{"status" => "ok"}} = OutputParser.parse(line, config)
  end

  test "parse stream_json ignores invalid envelope string payload" do
    config = %{format: :stream_json, extract: :last_json_line, envelope_path: "payload", success_status: "ok"}
    line = Jason.encode!(%{"payload" => "not-json"})

    assert :error = OutputParser.parse(line, config)
  end

  test "stream_complete? returns false for unparseable output" do
    config = AgentProfile.legacy_output()
    refute OutputParser.stream_complete?("garbage", config)
  end
end
