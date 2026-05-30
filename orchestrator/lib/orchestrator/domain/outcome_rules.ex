defmodule Orchestrator.Domain.OutcomeRules do
  @moduledoc """
  Per-node outcome rules from YAML (`outcome.success`, `outcome.failure`, …).

  Classification lives in `Outcome.Evaluator` (phase 2); this module holds the parsed rules.
  """

  alias Orchestrator.Domain.NodeDefinition

  @type t :: NodeDefinition.outcome_clause()

  @spec from_node(NodeDefinition.t()) :: t()
  def from_node(%NodeDefinition{outcome: outcome}), do: outcome
end
