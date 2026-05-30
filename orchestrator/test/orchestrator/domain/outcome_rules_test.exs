defmodule Orchestrator.Domain.OutcomeRulesTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.{OutcomeRules, RawResult}
  alias Orchestrator.Spec.Loader

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)

  setup do
    {:ok, program} = Loader.load(@fixture)
    {:ok, node: program.nodes[:mix_credo]}
  end

  test "exit_code 0 is success", %{node: node} do
    raw = %RawResult{exit_code: 0}
    assert %{status: :success, verdict_label: :success} = OutcomeRules.classify(node.outcome, raw)
  end

  test "non-zero exit is failure", %{node: node} do
    raw = %RawResult{exit_code: 1}
    assert %{status: :failure, verdict_label: :failure} = OutcomeRules.classify(node.outcome, raw)
  end

  test "unmatched result is unknown", %{node: node} do
    raw = %RawResult{exit_code: nil}
    assert %{status: :unknown, verdict_label: nil} = OutcomeRules.classify(node.outcome, raw)
  end

  test "llm timeout signal rules" do
    {:ok, program} = Loader.load(@fixture)
    node = program.nodes[:llm_fix]

    assert %{verdict_label: :failure} =
             OutcomeRules.classify(node.outcome, %RawResult{timed_out: true})

    assert %{verdict_label: :failure} =
             OutcomeRules.classify(node.outcome, %RawResult{signals: %{"refused" => true}})
  end
end
