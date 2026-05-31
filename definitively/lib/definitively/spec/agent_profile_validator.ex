defmodule Definitively.Spec.AgentProfileValidator do
  @moduledoc "Schema validation for loaded agent profiles."

  alias Definitively.Domain.AgentProfile
  alias Definitively.Spec.Error

  @prompt_modes ~w(argv_after_delimiter flag stdin)
  @output_formats ~w(stream_json json text)
  @extract_modes ~w(last_json_line whole_stdout)

  @doc "Validates a loaded agent profile struct."
  @spec validate(AgentProfile.t()) :: :ok | {:error, Error.t()}
  def validate(%AgentProfile{} = profile) do
    with :ok <- validate_executable(profile),
         :ok <- validate_prompt(profile) do
      validate_output(profile)
    end
  end

  defp validate_executable(%AgentProfile{executable: exe, executable_env: env}) do
    if is_binary(exe) or is_binary(env) do
      :ok
    else
      {:error,
       Error.new(
         :missing_executable,
         "agent profile must declare executable or executable_env"
       )}
    end
  end

  defp validate_prompt(%AgentProfile{prompt: %{mode: mode, flag: flag}}) do
    mode_str = to_string(mode)

    cond do
      mode_str not in @prompt_modes ->
        {:error,
         Error.new(
           :invalid_prompt_mode,
           "prompt.mode must be one of #{Enum.join(@prompt_modes, ", ")}, got #{inspect(mode)}"
         )}

      mode == :flag and not is_binary(flag) ->
        {:error, Error.new(:missing_prompt_flag, "prompt.flag is required when mode is flag")}

      true ->
        :ok
    end
  end

  defp validate_output(%AgentProfile{output: output}) when is_map(output) do
    format = output[:format] || output["format"]
    extract = output[:extract] || output["extract"]
    format_str = to_string(format || "")
    extract_str = to_string(extract || "")

    cond do
      format_str not in @output_formats ->
        {:error,
         Error.new(
           :invalid_output_format,
           "output.format must be one of #{Enum.join(@output_formats, ", ")}, got #{inspect(format)}"
         )}

      extract_str not in @extract_modes ->
        {:error,
         Error.new(
           :invalid_output_extract,
           "output.extract must be one of #{Enum.join(@extract_modes, ", ")}, got #{inspect(extract)}"
         )}

      true ->
        :ok
    end
  end
end
