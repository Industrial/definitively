defmodule Definitively.Init do
  @moduledoc """
  Scaffolds a `.definitively/` workspace by copying packaged templates.

  Uses `priv/templates/definitively/` when present (Mix dev/test). Escript installs
  fall back to compile-time embedded templates because escripts do not ship `priv/`.
  """

  alias Definitively.Templates

  @templates_rel ["priv", "templates", "definitively"]

  @doc """
  Copies template files into `<workspace>/.definitively/`.

  Workspace root is `DEFINITIVELY_WORKSPACE` when set, otherwise the current working directory.
  Existing destination files are skipped unless `force: true` (CLI `--force`).

  ## Options

    * `:force` — overwrite existing destination files
    * `:workspace_root` — override workspace root (tests)
    * `:templates_source` — `:filesystem` or `:embedded` to force a source (tests)
  """
  @spec run(keyword()) ::
          {:ok, %{created: [Path.t()], skipped: [Path.t()]}} | {:error, term()}
  def run(opts \\ []) do
    force = Keyword.get(opts, :force, false)
    workspace = workspace_root(opts)
    dest = Path.join(workspace, ".definitively")

    case resolve_templates(opts) do
      {:dir, src} ->
        {:ok, copy_from_dir(src, dest, force)}

      {:embedded, manifest} ->
        {:ok, write_embedded(manifest, dest, force)}

      :missing ->
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

  defp resolve_templates(opts) do
    case Keyword.get(opts, :templates_source) do
      :embedded -> embedded_source() || :missing
      :filesystem -> filesystem_source() || :missing
      nil -> filesystem_source() || embedded_source() || :missing
    end
  end

  defp filesystem_source do
    src =
      Application.get_env(:definitively, :templates_dir) ||
        Application.app_dir(:definitively, @templates_rel)

    if File.dir?(src), do: {:dir, src}
  end

  defp embedded_source do
    case Templates.manifest() do
      %{} = manifest when map_size(manifest) > 0 -> {:embedded, manifest}
      _ -> nil
    end
  end

  defp copy_from_dir(src, dest, force) do
    src
    |> template_files()
    |> Enum.reduce(%{created: [], skipped: []}, fn abs_src, acc ->
      rel = Path.relative_to(abs_src, src)
      abs_dest = Path.join(dest, rel)
      copy_file(abs_src, abs_dest, force, acc)
    end)
    |> reverse_results()
  end

  defp write_embedded(manifest, dest, force) do
    manifest
    |> Enum.sort_by(fn {rel, _} -> rel end)
    |> Enum.reduce(%{created: [], skipped: []}, fn {rel, content}, acc ->
      abs_dest = Path.join(dest, rel)
      write_file(abs_dest, content, force, acc)
    end)
    |> reverse_results()
  end

  defp copy_file(src, dest, force, acc) do
    if File.exists?(dest) and not force do
      %{acc | skipped: [dest | acc.skipped]}
    else
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(src, dest)
      %{acc | created: [dest | acc.created]}
    end
  end

  defp write_file(dest, content, force, acc) do
    if File.exists?(dest) and not force do
      %{acc | skipped: [dest | acc.skipped]}
    else
      File.mkdir_p!(Path.dirname(dest))
      File.write!(dest, content)
      %{acc | created: [dest | acc.created]}
    end
  end

  defp reverse_results(acc) do
    acc
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
