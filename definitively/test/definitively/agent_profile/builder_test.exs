defmodule Definitively.AgentProfile.BuilderTest do
  use ExUnit.Case, async: true

  alias Definitively.AgentProfile.Builder
  alias Definitively.Domain.{AgentProfile, NodeDefinition}

  test "builds argv with model interpolation and prompt after delimiter" do
    profile = %AgentProfile{
      executable: "agent-cli",
      argv: ["run", "--model", "{{model}}", "--"],
      prompt: %{mode: :argv_after_delimiter, flag: nil},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm, model: "gpt-4"}

    assert {:ok, {"agent-cli", ["run", "--model", "gpt-4", "--", "hello"]}} =
             Builder.build(profile, node, "hello")
  end

  test "builds flag prompt mode" do
    profile = %AgentProfile{
      executable: "agent-cli",
      argv: ["run"],
      prompt: %{mode: :flag, flag: "-p"},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm, model: "auto"}

    assert {:ok, {"agent-cli", ["run", "-p", "prompt text"]}} =
             Builder.build(profile, node, "prompt text")
  end

  test "resolves executable_env" do
    System.put_env("TEST_AGENT_EXE", "/bin/echo")
    on_exit(fn -> System.delete_env("TEST_AGENT_EXE") end)

    profile = %AgentProfile{
      executable_env: "TEST_AGENT_EXE",
      argv: [],
      prompt: %{mode: :stdin, flag: nil},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm}

    assert {:ok, {"/bin/echo", [], "stdin prompt"}} = Builder.build(profile, node, "stdin prompt")
  end
test "returns error when executable_env is unset" do
    profile = %AgentProfile{
      executable_env: "MISSING_AGENT_EXE_VAR",
      argv: [],
      prompt: %{mode: :stdin, flag: nil},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm}

    assert {:error, {:missing_executable_env, "MISSING_AGENT_EXE_VAR"}} =
             Builder.build(profile, node, "prompt")
  end

  test "returns error when executable is missing" do
    profile = %AgentProfile{
      argv: [],
      prompt: %{mode: :stdin, flag: nil},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm}

    assert {:error, :missing_executable} = Builder.build(profile, node, "prompt")
  end

  test "reuses trailing delimiter in argv when present" do
    profile = %AgentProfile{
      executable: "agent-cli",
      argv: ["run", "--"],
      prompt: %{mode: :argv_after_delimiter, flag: nil},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm, model: "auto"}

    assert {:ok, {"agent-cli", ["run", "--", "hello"]}} = Builder.build(profile, node, "hello")
  end

  test "leaves argv unchanged for unknown prompt mode" do
    profile = %AgentProfile{
      executable: "agent-cli",
      argv: ["run"],
      prompt: %{mode: :unknown, flag: nil},
      output: AgentProfile.legacy_output()
    }

    node = %NodeDefinition{kind: :llm, model: "auto"}

    assert {:ok, {"agent-cli", ["run"]}} = Builder.build(profile, node, "ignored")
  end
end
