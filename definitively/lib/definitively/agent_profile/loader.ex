defmodule Definitively.AgentProfile.Loader do
  @moduledoc "Load YAML agent profiles from `.definitively/agents/`."

  alias Definitively.Domain.AgentProfile
  alias Definitively.Spec.{AgentProfileValidator, Error}

  @agents_dir ".definitively/agents"

  @doc """
  Loads a single agent profile by id from `workspace_root/.definitively/agents/<id>.yml`.
  """
  @spec load(atom() | String.t(), Path.t()) :: {:ok, AgentProfile.t()} | {:error, Error.t()}
  def load(id, workspace_root) when is_atom(id) or is_binary(id) do
    id_str = to_string(id)
    path = Path.join([workspace_root, @agents_dir, "#{id_str}.yml"])

    with {:ok, raw} <- read_yaml(path),
         {:ok, profile} <- build_profile(raw, id_str, path),
         :ok <- AgentProfileValidator.validate(profile) do
      {:ok, profile}
    end
  end

  defp read_yaml(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:error, reason} ->
        if file_not_found?(reason) do
          {:error, Error.new(:agent_profile_not_found, "agent profile not found: #{path}", path)}
        else
          {:error,
           Error.new(
             :invalid_agent_yaml,
             "failed to parse agent profile: #{inspect(reason)}",
             path
           )}
        end
    end
  end

  defp file_not_found?(:enoent), do: true

  defp file_not_found?(%YamlElixir.FileNotFoundError{}), do: true
  defp file_not_found?(_), do: false

  defp build_profile(raw, id_str, path) do
    case Map.get(raw, "agent") do
      %{} = section ->
        with {:ok, profile_id} <- profile_id(section, id_str, path) do
          {:ok,
           %AgentProfile{
             id: profile_id,
             executable: Map.get(section, "executable"),
             executable_env: Map.get(section, "executable_env"),
             argv: parse_argv(Map.get(section, "argv", []), path),
             prompt: parse_prompt(Map.get(section, "prompt", %{})),
             output: parse_output(Map.get(section, "output", %{}))
           }}
        end

      _ ->
        {:error,
         Error.new(:invalid_agent_profile, "agent profile must include top-level agent map", path)}
    end
  end

  defp profile_id(%{"id" => id}, filename_id, path) when is_binary(id) do
    if id == filename_id do
      {:ok, String.to_atom(id)}
    else
      {:error,
       Error.new(
         :agent_id_mismatch,
         "agent.id #{inspect(id)} must match filename #{filename_id}.yml",
         path
       )}
    end
  end

  defp profile_id(_, filename_id, _path), do: {:ok, String.to_atom(filename_id)}

  defp parse_argv(argv, _path) when is_list(argv), do: Enum.map(argv, &to_string/1)
  defp parse_argv(_, _path), do: []

  defp parse_prompt(prompt) when is_map(prompt) do
    mode =
      case Map.get(prompt, "mode", "argv_after_delimiter") do
        m when m in ["argv_after_delimiter", "flag", "stdin"] -> String.to_atom(m)
        _ -> :argv_after_delimiter
      end

    %{mode: mode, flag: Map.get(prompt, "flag")}
  end

  defp parse_output(output) when is_map(output) do
    %{
      format: atom_field(output, "format", "json", ~w(stream_json json text)),
      extract: atom_field(output, "extract", "whole_stdout", ~w(last_json_line whole_stdout)),
      envelope_path: Map.get(output, "envelope_path"),
      success_status: Map.get(output, "success_status", "ok")
    }
  end

  defp atom_field(map, key, default, allowed) do
    value = Map.get(map, key, default)

    if to_string(value) in allowed do
      String.to_atom(to_string(value))
    else
      String.to_atom(default)
    end
  end
end
