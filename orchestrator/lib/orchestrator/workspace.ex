defmodule Orchestrator.Workspace do

  alias Orchestrator.Log
  @moduledoc """
  Resolves an absolute program path and workspace root from a workflow YAML file.

  Workspace root is the directory that contains `.orchestrator/` (parent of that folder).
  Programs are expected at `.orchestrator/programs/*.yml` but any path under
  `.orchestrator/` in an ancestor tree is accepted.

  When layout detection fails, `ORCHESTRATOR_WORKSPACE` may supply the root if the
  program path lies inside that directory (tests and explicit overrides).
  """

  @type resolved :: %{
          program_path: Path.t(),
          workspace_root: Path.t()
        }

  @doc """
  Expands `program_path` to an absolute file and discovers `workspace_root`.

  Returns `{:error, :enoent}` when the file is missing, or `{:error, :no_orchestrator_layout}`
  when no workspace can be determined.
  """
  @spec resolve_run(Path.t()) :: {:ok, resolved()} | {:error, :enoent | :no_orchestrator_layout}
  def resolve_run(program_path) when is_binary(program_path) do
    path = Path.expand(program_path)

    if File.regular?(path) do
      workspace_root = find_workspace_root(path) || workspace_from_env(path)

      if workspace_root do
        Log.debug("workspace resolved",
          path: path,
          workspace: workspace_root
        )

        {:ok, %{program_path: path, workspace_root: workspace_root}}
      else
        Log.warn("no .orchestrator layout for program", path: path)
        {:error, :no_orchestrator_layout}
      end
    else
      Log.warn("program file not found", path: path)
      {:error, :enoent}
    end
  end

  defp find_workspace_root(program_path) do
    program_path
    |> Path.dirname()
    |> Stream.iterate(&Path.dirname/1)
    |> Enum.reduce_while(nil, fn dir, _ ->
      orch_dir = Path.join(dir, ".orchestrator")

      cond do
        workspace_for_orchestrator?(orch_dir, program_path) ->
          {:halt, dir}

        dir == Path.dirname(dir) ->
          {:halt, nil}

        true ->
          {:cont, nil}
      end
    end)
  end

  defp workspace_from_env(program_path) do
    case System.get_env("ORCHESTRATOR_WORKSPACE") do
      nil ->
        nil

      root ->
        root = Path.expand(root)

        if String.starts_with?(program_path, root <> "/") or program_path == root do
          root
        else
          nil
        end
    end
  end

  defp workspace_for_orchestrator?(orch_dir, program_path) do
    File.dir?(orch_dir) and String.starts_with?(program_path, orch_dir <> "/")
  end
end
