defmodule Definitively.Spec.ValidatorTest do
  use ExUnit.Case, async: true

  alias Definitively.Spec.{Error, Loader, Validator}

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)
  @invalid Path.expand("../../fixtures/invalid_transition.yml", __DIR__)
  @invalid_initial Path.expand("../../fixtures/invalid_initial.yml", __DIR__)
  @active_missing Path.expand("../../fixtures/active_missing_node.yml", __DIR__)
  @undefined_node Path.expand("../../fixtures/undefined_node_ref.yml", __DIR__)

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

  test "rejects invalid initial state via loader" do
    assert {:error, %Error{reason: :invalid_initial}} = Loader.load(@invalid_initial)
  end

  test "rejects active state without node ref" do
    assert {:error, %Error{reason: :missing_node_ref}} = Loader.load(@active_missing)
  end

  test "rejects undefined node reference" do
    assert {:error, %Error{reason: :undefined_node}} = Loader.load(@undefined_node)
  end

  test "rejects cli node without command" do
    path = Path.join(System.tmp_dir!(), "validator-cli-#{System.unique_integer()}.yml")

    File.write!(path, """
    program:
      id: bad_cli
      version: 1
      initial: run
    states:
      run:
        type: active
        node: cmd
        on:
          success: done
      done:
        type: final
    nodes:
      cmd:
        kind: cli
        outcome:
          success:
            - exit_code: 0
    """)

    on_exit(fn -> File.rm(path) end)
    assert {:error, %Error{reason: :missing_command}} = Loader.load(path)
  end

  test "rejects git node without action" do
    path = Path.join(System.tmp_dir!(), "validator-git-#{System.unique_integer()}.yml")

    File.write!(path, """
    program:
      id: bad_git
      version: 1
      initial: run
    states:
      run:
        type: active
        node: git
        on:
          success: done
      done:
        type: final
    nodes:
      git:
        kind: git
        outcome:
          success:
            - exit_code: 0
    """)

    on_exit(fn -> File.rm(path) end)
    assert {:error, %Error{reason: :missing_action}} = Loader.load(path)
  end
end
