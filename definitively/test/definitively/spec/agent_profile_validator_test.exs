defmodule Definitively.Spec.AgentProfileValidatorTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.AgentProfile
  alias Definitively.Spec.{AgentProfileValidator, Error}

  defp base_profile(overrides \\ []) do
    struct(
      %AgentProfile{
        id: :test,
        executable: "echo",
        argv: [],
        prompt: %{mode: :argv_after_delimiter, flag: nil},
        output: AgentProfile.legacy_output()
      },
      overrides
    )
  end

  test "accepts valid profile" do
    assert :ok = AgentProfileValidator.validate(base_profile())
  end

  test "rejects profile without executable or executable_env" do
    assert {:error, %Error{reason: :missing_executable}} =
             AgentProfileValidator.validate(base_profile(executable: nil))
  end

  test "rejects invalid prompt mode" do
    assert {:error, %Error{reason: :invalid_prompt_mode}} =
             AgentProfileValidator.validate(
               base_profile(prompt: %{mode: :unknown, flag: nil})
             )
  end

  test "rejects flag mode without prompt flag" do
    assert {:error, %Error{reason: :missing_prompt_flag}} =
             AgentProfileValidator.validate(
               base_profile(prompt: %{mode: :flag, flag: nil})
             )
  end

  test "rejects invalid output format" do
    output = Map.put(AgentProfile.legacy_output(), :format, :xml)

    assert {:error, %Error{reason: :invalid_output_format}} =
             AgentProfileValidator.validate(base_profile(output: output))
  end

  test "rejects invalid output extract mode" do
    output = Map.put(AgentProfile.legacy_output(), :extract, :first_line)

    assert {:error, %Error{reason: :invalid_output_extract}} =
             AgentProfileValidator.validate(base_profile(output: output))
  end
end
