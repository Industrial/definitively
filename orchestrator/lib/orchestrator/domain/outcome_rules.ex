defmodule Orchestrator.Domain.OutcomeRules do
  @moduledoc """
  Per-node outcome rules from YAML; classifies `RawResult` into `Outcome`.
  """

  alias Orchestrator.Domain.{NodeDefinition, Predicate, RawResult}
  alias Orchestrator.Log
  alias Orchestrator.Outcome

  @type t :: NodeDefinition.outcome_clause()

  @doc "Returns the outcome rule map from a node definition."
  @spec from_node(NodeDefinition.t()) :: t()
  def from_node(%NodeDefinition{outcome: outcome}), do: outcome

  @doc "Classifies a raw node result using the given outcome rules."
  @spec classify(t(), RawResult.t()) :: Outcome.t()
  def classify(rules, %RawResult{} = raw) when is_map(rules) do
    label =
      rules
      |> Enum.find_value(fn {label, clauses} ->
        if clause_list_matches?(clauses, raw), do: label
      end)

    outcome = build_outcome(label, raw)

    Log.debug("outcome classified",
      label: outcome.verdict_label,
      status: outcome.status,
      exit_code: outcome.exit_code,
      timed_out: raw.timed_out
    )

    outcome
  end

  defp clause_list_matches?(clauses, raw) when is_list(clauses) do
    Enum.any?(clauses, &Predicate.matches?(&1, raw))
  end

  defp clause_list_matches?(_, _), do: false

  defp build_outcome(nil, raw) do
    %Outcome{
      status: :unknown,
      verdict_label: nil,
      exit_code: raw.exit_code,
      raw: raw_summary(raw)
    }
  end

  defp build_outcome(label, raw) do
    %Outcome{
      status: status_for_label(label),
      verdict_label: label,
      exit_code: raw.exit_code,
      signals: raw.signals,
      raw: raw_summary(raw)
    }
  end

  defp status_for_label(:success), do: :success
  defp status_for_label(:failure), do: :failure
  defp status_for_label(:partial), do: :partial
  defp status_for_label(:retry), do: :failure
  defp status_for_label(:abort), do: :failure
  defp status_for_label(_), do: :unknown

  defp raw_summary(%RawResult{} = raw) do
    %{
      exit_code: raw.exit_code,
      timed_out: raw.timed_out,
      duration_ms: raw.duration_ms,
      stdout_bytes: byte_size(raw.stdout),
      stderr_bytes: byte_size(raw.stderr)
    }
  end
end
