defmodule Definitively.CLI do
  @moduledoc "Command-line interface for workflow runs and program visualization."

  alias Definitively.Init
  alias Definitively.Log
  alias Definitively.Log.RunFile
  alias Definitively.Run.Coordinator
  alias Definitively.Visualize
  alias Definitively.Workspace

  @doc "Entry point for the definitively command-line interface."
  @spec main([String.t()]) :: :ok | no_return()
  def main(argv \\ []) do
    {:ok, _} = Application.ensure_all_started(:definitively)
    Log.configure!()

    case dispatch(argv) do
      :ok ->
        print_success(argv)
        RunFile.clear_run_log_path!()
        :ok

      :usage ->
        usage()
        System.halt(1)

      {:error, reason, code} ->
        IO.puts(:stderr, format_error(reason))
        System.halt(code)
    end
  end

  @doc false
  @spec dispatch([String.t()]) :: :ok | {:error, term(), non_neg_integer()} | :usage
  def dispatch(argv) do
    case argv do
      ["run", program_path | _opts] ->
        dispatch_run(program_path)

      ["visualize", program_path | rest] ->
        dispatch_visualize(program_path, rest)

      ["init" | rest] ->
        dispatch_init(rest)

      _ ->
        :usage
    end
  end

  defp dispatch_run(program_path) do
    case Workspace.resolve_run(program_path) do
      {:ok, resolved} ->
        run_resolved_program(resolved)

      {:error, :enoent} ->
        {:error, :invalid_program_path, 1}

      {:error, :no_definitively_layout} ->
        {:error, :no_definitively_layout, 1}

      {:error, reason} ->
        {:error, reason, 1}
    end
  end

  defp run_resolved_program(resolved) do
    opts = run_opts(resolved)

    case RunFile.with_log(resolved.workspace_root, resolved.program_path, opts, fn opts ->
           Log.info("run requested",
             program: resolved.program_path,
             workspace: resolved.workspace_root
           )

           Coordinator.run_until_final(resolved.program_path, opts)
         end) do
      :ok ->
        :ok

      {:error, :awaiting_approval} ->
        {:error, :awaiting_approval, 2}

      {:error, reason} ->
        Log.error("workflow failed", error: inspect(reason))
        {:error, reason, 1}
    end
  end

  defp dispatch_init(rest) do
    force = "--force" in rest

    case Init.run(force: force) do
      {:ok, %{created: created, skipped: skipped}} ->
        print_init_summary(created, skipped)
        :ok

      {:error, reason} ->
        {:error, reason, 1}
    end
  end

  defp dispatch_visualize(program_path, rest) do
    case Visualize.cli_render(program_path, rest) do
      {:ok, {:files, paths}} ->
        Enum.each(paths, &IO.puts/1)
        :ok

      {:error, reason} ->
        {:error, reason, 1}
    end
  end

  defp run_opts(%{workspace_root: discovered}) do
    root = System.get_env("DEFINITIVELY_WORKSPACE", discovered)
    [workspace_root: root]
  end

  defp format_error(:invalid_program_path),
    do: "program file not found — pass the full path to a .yml file"

  defp format_error(:no_definitively_layout),
    do: "program must live under a .definitively/ directory (workspace root is its parent)"

  defp format_error(:awaiting_approval),
    do: "workflow stopped at an approval gate that could not be auto-approved"

  defp format_error({:graphviz_unavailable, %ErlangError{original: :enoent}, opts})
       when is_list(opts) do
    dot_suffix(opts) <>
      "graphviz `dot` not found on PATH — run inside `devenv shell` (graphviz is in devenv.nix) or use --format dot"
  end

  defp format_error({:graphviz_unavailable, reason, opts}) when is_list(opts) do
    dot_suffix(opts) <>
      "graphviz render failed (install `dot` or use --format dot): #{inspect(reason)}"
  end

  defp format_error({:graphviz_unavailable, %ErlangError{original: :enoent}}),
    do:
      "graphviz `dot` not found on PATH — run inside `devenv shell` (graphviz is in devenv.nix) or use --format dot"

  defp format_error({:graphviz_unavailable, reason}),
    do: "graphviz render failed (install `dot` or use --format dot): #{inspect(reason)}"

  defp format_error(:templates_missing),
    do: "definitively templates not found — reinstall or rebuild the definitively package"

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: "workflow failed: #{inspect(reason)}"

  defp dot_suffix(opts) do
    case Keyword.get(opts, :dot_path) do
      nil -> ""
      path -> "DOT written to #{path} — "
    end
  end

  defp print_success(["run" | _]) do
    case RunFile.active_log_path() do
      nil ->
        IO.puts("workflow finished")

      path ->
        line = "workflow finished — log: #{path}\n"
        RunFile.write_output(line)
        IO.write(:stdio, line)
    end
  end
  defp print_success(["visualize" | _]), do: :ok
  defp print_success(["init" | _]), do: :ok
  defp print_success(_), do: :ok

  defp print_init_summary(created, skipped) do
    Enum.each(created, fn path -> IO.puts("created #{path}") end)
    Enum.each(skipped, fn path -> IO.puts("skipped #{path} (exists)") end)

    if created == [] and skipped == [] do
      IO.puts("no template files found")
    else
      IO.puts("definitively workspace initialized")
    end
  end

  defp usage do
    IO.puts(:stderr, """
    Usage:
      definitively init [--force]
      definitively run </full/path/to/program.yml>
      definitively visualize </full/path/to/program.yml> [--format dot|png|svg] [--out <basename>]

    init copies priv templates into .definitively/ under the workspace (cwd or DEFINITIVELY_WORKSPACE).
    Workspace root is inferred from the program path (parent of .definitively/).
    Default visualize writes DOT and PNG to .definitively/visualizations/.
    Override workspace with DEFINITIVELY_WORKSPACE if needed.
    """)
  end
end
