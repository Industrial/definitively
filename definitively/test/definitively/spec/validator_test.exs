defmodule Definitively.Spec.ValidatorTest do
  use ExUnit.Case, async: true

  alias Definitively.Spec.{Error, Loader, Validator}

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)
  @invalid Path.expand("../../fixtures/invalid_transition.yml", __DIR__)

  test "validates good fixture" do
    assert {:ok, program} = Loader.load(@fixture)
    assert :ok = Validator.validate(program)
  end

  test "rejects transition to undefined state" do
    assert {:error, %Error{reason: :invalid_transition}} = Loader.load(@invalid)
  end

  test "rejects program without final states" do
    path = Path.expand("../../fixtures/no_final_state.yml", __DIR__)
    assert {:error, %Error{reason: :no_final_state}} = Loader.load(path)
  end

  test "rejects unreachable final states" do
    path = Path.expand("../../fixtures/unreachable_final.yml", __DIR__)
    assert {:error, %Error{reason: :unreachable_final}} = Loader.load(path)
  end

  test "rejects llm node with both agent and command" do
    path = Path.expand("../../fixtures/llm_agent_command_conflict.yml", __DIR__)
    assert {:error, %Error{reason: :conflicting_llm_source}} = Loader.load(path)
  end

  test "rejects llm node without prompt_file" do
    path = Path.expand("../../fixtures/llm_missing_prompt.yml", __DIR__)
    assert {:error, %Error{reason: :missing_prompt_file}} = Loader.load(path)
  end
end
