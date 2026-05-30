defmodule Orchestrator.Outcome.Evaluator do
  @moduledoc "Boundary: classify `RawResult` using a node's outcome rules."

  alias Orchestrator.Domain.{NodeDefinition, OutcomeRules, RawResult}
  alias Orchestrator.Outcome

  @spec evaluate(NodeDefinition.t(), RawResult.t()) :: Outcome.t()
  def evaluate(%NodeDefinition{} = node, %RawResult{} = raw) do
    node |> OutcomeRules.from_node() |> OutcomeRules.classify(raw)
  end
end
