defmodule Orchestrator.Outcome.Evaluator do
  @moduledoc "Boundary: classify `RawResult` using a node's outcome rules."

  alias Orchestrator.Domain.{NodeDefinition, OutcomeRules, RawResult}
  alias Orchestrator.Log
  alias Orchestrator.Outcome

  @doc "Evaluates a node's outcome rules against a raw execution result."
  @spec evaluate(NodeDefinition.t(), RawResult.t()) :: Outcome.t()
  def evaluate(%NodeDefinition{} = node, %RawResult{} = raw) do
    Log.trace("evaluating node outcome rules", node_id: node.id, kind: node.kind)
    node |> OutcomeRules.from_node() |> OutcomeRules.classify(raw)
  end
end
