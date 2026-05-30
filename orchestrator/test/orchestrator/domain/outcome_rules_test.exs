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

  test "from_node/1 returns node outcome rules" do
    {:ok, program} = Loader.load(@fixture)
    node = program.nodes[:mix_credo]

    assert OutcomeRules.from_node(node) == node.outcome
  end

  test "classifies partial, retry, abort, and unknown labels" do
    rules = %{
      partial: [%{exit_code: 0}],
      retry: [%{exit_code: 1}],
      abort: [%{exit_code: 2}],
      weird: [%{exit_code: 3}]
    }

    assert %{status: :partial, verdict_label: :partial} =
             OutcomeRules.classify(rules, %RawResult{exit_code: 0})

    assert %{status: :failure, verdict_label: :retry} =
             OutcomeRules.classify(rules, %RawResult{exit_code: 1})

    assert %{status: :failure, verdict_label: :abort} =
             OutcomeRules.classify(rules, %RawResult{exit_code: 2})

    assert %{status: :unknown, verdict_label: :weird} =
             OutcomeRules.classify(rules, %RawResult{exit_code: 3})
  end

  test "includes raw summary bytes in unknown outcomes" do
    raw = %RawResult{
      exit_code: nil,
      timed_out: false,
      duration_ms: 12,
      stdout: "hello",
      stderr: "!"
    }

    assert %{
             status: :unknown,
             raw: %{stdout_bytes: 5, stderr_bytes: 1, duration_ms: 12}
           } =
             OutcomeRules.classify(%{success: [%{exit_code: 0}]}, raw)
  end

  test "invalid clause lists never match" do
    assert %{status: :unknown} =
             OutcomeRules.classify(%{success: "not-a-list"}, %RawResult{exit_code: 0})
  end
end
