defmodule Definitively.Nodes.Llm.Stub do
  @moduledoc false

  alias Definitively.Domain.RawResult

  @doc "Returns a synthetic successful LLM JSON envelope for tests."
  @spec run(term(), term(), String.t()) :: {:ok, RawResult.t()}
  def run(_node, _ctx, _prompt) do
    {:ok,
     %RawResult{
       exit_code: 0,
       stdout: ~s({"status":"ok","signals":{"fix_complete":true}}),
       llm_json: %{"status" => "ok", "signals" => %{"fix_complete" => true}},
       signals: %{"fix_complete" => true}
     }}
  end
end
