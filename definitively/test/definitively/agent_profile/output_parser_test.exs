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
end
