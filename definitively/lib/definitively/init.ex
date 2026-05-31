defmodule Definitively.Init do
  @moduledoc """
  Scaffolds a `.definitively/` workspace by copying packaged templates from `priv/`.
  """

  @templates_rel ["priv", "templates", "definitively"]

  @doc """
  Copies template files into `<workspace>/.definitively/`.

  Workspace root is `DEFINITIVELY_WORKSPACE` when set, otherwise the current working directory.
  Existing destination files are skipped unless `force: true` (CLI `--force`).
  """
  @spec run(keyword()) ::
          {:ok, %{created: [Path.t()], skipped: [Path.t()]}} | {:error, term()}
  def run(opts \\ []) do
    force = Keyword.get(opts, :force, false)
    workspace = workspace_root(opts)
    src = templates_root()
    dest = Path.join(workspace, ".definitively")

    if File.dir?(src) do
      {:ok, copy_templates(src, dest, force)}
    else
      {:error, :templates_missing}
    end
  end

  defp workspace_root(opts) do
    Keyword.get_lazy(opts, :workspace_root, fn ->
      case System.get_env("DEFINITIVELY_WORKSPACE") do
        nil -> File.cwd!() |> Path.expand()
        root -> Path.expand(root)
      end
    end)
  end

  defp templates_root do
    Application.app_dir(:definitively, @templates_rel)
  end

  defp copy_templates(src, dest, force) do
    src
    |> template_files()
    |> Enum.reduce(%{created: [], skipped: []}, fn abs_src, acc ->
      rel = Path.relative_to(abs_src, src)
      abs_dest = Path.join(dest, rel)

      if File.exists?(abs_dest) and not force do
        %{acc | skipped: [abs_dest | acc.skipped]}
      else
        File.mkdir_p!(Path.dirname(abs_dest))
        File.cp!(abs_src, abs_dest)
        %{acc | created: [abs_dest | acc.created]}
      end
    end)
    |> Map.update!(:created, &Enum.reverse/1)
    |> Map.update!(:skipped, &Enum.reverse/1)
  end

  defp template_files(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
  end
end
