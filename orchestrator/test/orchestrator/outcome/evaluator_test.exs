defmodule Orchestrator.Outcome.EvaluatorTest do
  use ExUnit.Case, async: true

  alias Orchestrator.Domain.RawResult
  alias Orchestrator.Outcome.Evaluator
  alias Orchestrator.Spec.Loader

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)

  test "delegates to outcome rules" do
    {:ok, program} = Loader.load(@fixture)
    node = program.nodes[:git_commit]
    raw = %RawResult{exit_code: 0}

    assert %{status: :success, verdict_label: :success} = Evaluator.evaluate(node, raw)
  end
end
