defmodule Definitively.AgentProfile.Builder do
  @moduledoc "Builds subprocess argv from an agent profile, node, and prompt."

  alias Definitively.Domain.{AgentProfile, NodeDefinition}

  @type build_result :: {String.t(), [String.t()]}
  @type stdin_build_result :: {String.t(), [String.t()], String.t()}

  @doc """
  Resolves executable and argv for an agent profile invocation.

  Returns `{:ok, {executable, argv}}` or `{:ok, {executable, argv, prompt}}` for stdin mode.
  """
  @spec build(AgentProfile.t(), NodeDefinition.t(), String.t()) ::
          {:ok, build_result() | stdin_build_result()} | {:error, term()}
  def build(%AgentProfile{} = profile, %NodeDefinition{} = node, prompt) do
    with {:ok, executable} <- resolve_executable(profile),
         {:ok, argv} <- build_argv(profile, node) do
      case profile.prompt.mode do
        :stdin -> {:ok, {executable, argv, prompt}}
        _ -> {:ok, {executable, append_prompt(argv, profile.prompt, prompt)}}
      end
    end
  end

  @doc false
  @spec resolve_executable(AgentProfile.t()) :: {:ok, String.t()} | {:error, term()}
  def resolve_executable(%AgentProfile{executable_env: env}) when is_binary(env) do
    case System.get_env(env) do
      nil -> {:error, {:missing_executable_env, env}}
      exe -> {:ok, exe}
    end
  end

  def resolve_executable(%AgentProfile{executable: exe}) when is_binary(exe), do: {:ok, exe}

  def resolve_executable(_), do: {:error, :missing_executable}

  defp build_argv(%AgentProfile{argv: argv}, %NodeDefinition{model: model}) do
    model = model || "auto"
    {:ok, Enum.map(argv, &interpolate(&1, model))}
  end

  defp interpolate("{{model}}", model), do: model

  defp interpolate(str, model) when is_binary(str),
    do: String.replace(str, "{{model}}", model)

  defp append_prompt(argv, %{mode: :argv_after_delimiter}, prompt) do
    case Enum.split(argv, -1) do
      {prefix, ["--"]} -> prefix ++ ["--", prompt]
      _ -> argv ++ ["--", prompt]
    end
  end

  defp append_prompt(argv, %{mode: :flag, flag: flag}, prompt) when is_binary(flag) do
    argv ++ [flag, prompt]
  end

  defp append_prompt(argv, _, _prompt), do: argv
end
