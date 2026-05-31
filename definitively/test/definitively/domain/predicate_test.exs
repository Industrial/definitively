defmodule Definitively.Domain.PredicateTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.{Predicate, RawResult}

  test "exit_code exact match" do
    raw = %RawResult{exit_code: 0}
    assert Predicate.matches?(%{exit_code: 0}, raw)
    refute Predicate.matches?(%{exit_code: 1}, raw)
  end

  test "exit_code neq with string and atom keys" do
    raw = %RawResult{exit_code: 2}

    assert Predicate.matches?(%{exit_code: %{"neq" => 0}}, raw)
    assert Predicate.matches?(%{exit_code: %{neq: 0}}, raw)
    refute Predicate.matches?(%{exit_code: %{"neq" => 2}}, raw)
  end

  test "exit_code neq is false when code is nil" do
    refute Predicate.matches?(%{exit_code: %{"neq" => 0}}, %RawResult{exit_code: nil})
  end

  test "timeout predicate" do
    assert Predicate.matches?(%{timeout: true}, %RawResult{timed_out: true})
    refute Predicate.matches?(%{timeout: true}, %RawResult{timed_out: false})
    refute Predicate.matches?(%{timeout: false}, %RawResult{timed_out: true})
  end

  test "signal predicate with string and atom keys" do
    raw = %RawResult{signals: %{"refused" => true, done: "true"}}

    assert Predicate.matches?(%{signal: "refused"}, raw)
    assert Predicate.matches?(%{signal: "done"}, raw)
    refute Predicate.matches?(%{signal: "missing"}, raw)
  end

  test "signal truthy accepts common representations" do
    for value <- [true, "true", 1] do
      raw = %RawResult{signals: %{"flag" => value}}
      assert Predicate.matches?(%{signal: "flag"}, raw)
    end

    refute Predicate.matches?(%{signal: "flag"}, %RawResult{signals: %{"flag" => false}})
  end

  test "jq on llm_json status ok" do
    raw = %RawResult{llm_json: %{"status" => "ok"}}

    assert Predicate.matches?(%{jq: ~s(.status == "ok")}, raw)
    refute Predicate.matches?(%{jq: ~s(.status == "ok")}, %RawResult{llm_json: %{"status" => "fail"}})
  end

  test "jq and unknown clauses do not match bare raw" do
    raw = %RawResult{exit_code: 0}

    refute Predicate.matches?(%{jq: ".ok"}, raw)
    refute Predicate.matches?(%{unknown: true}, raw)
    refute Predicate.matches?(%{exit_code: "bad"}, raw)
  end
end
