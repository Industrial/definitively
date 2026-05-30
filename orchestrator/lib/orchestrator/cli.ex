defmodule Orchestrator.CLI do
  @moduledoc "Command-line interface for workflow runs and program visualization."

  alias Orchestrator.Init
  alias Orchestrator.Log
  alias Orchestrator.Run.Coordinator
  alias Orchestrator.Visualize
  alias Orchestrator.Workspace

  @doc "Entry point for the orchestrator command-line interface."
  @spec main([String.t()]) :: :ok | no_return()
  def main(argv \\ []) do
    {:ok, _} = Application.ensure_all_started(:orchestrator)
    Log.configure!()

    case dispatch(argv) do
      :ok ->
        print_success(argv)
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
        Log.info("run requested",
          program: resolved.program_path,
          workspace: resolved.workspace_root
        )

        opts = run_opts(resolved)
        start_and_resume(resolved.program_path, opts)

      {:error, :enoent} ->
        {:error, :invalid_program_path, 1}

      {:error, :no_orchestrator_layout} ->
        {:error, :no_orchestrator_layout, 1}

      {:error, reason} ->
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

  defp start_and_resume(program_path, opts) do
    case Coordinator.start(program_path, opts) do
      {:ok, run_id} ->
        case Coordinator.resume(run_id, opts) do
          :ok ->
            Log.info("workflow completed", run_id: run_id)
            :ok

          {:error, :awaiting_approval} ->
            {:error, :awaiting_approval, 2}

          {:error, reason} ->
            Log.error("workflow failed", run_id: run_id, error: inspect(reason))
            {:error, reason, 1}
        end

      {:error, reason} ->
        {:error, reason, 1}
    end
  end

  defp run_opts(%{workspace_root: discovered}) do
    root = System.get_env("ORCHESTRATOR_WORKSPACE", discovered)
    [workspace_root: root]
  end

  defp format_error(:invalid_program_path),
    do: "program file not found — pass the full path to a .yml file"

  defp format_error(:no_orchestrator_layout),
    do: "program must live under a .orchestrator/ directory (workspace root is its parent)"

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
    do: "orchestrator templates not found — reinstall or rebuild the orchestrator package"

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: "workflow failed: #{inspect(reason)}"

  defp dot_suffix(opts) do
    case Keyword.get(opts, :dot_path) do
      nil -> ""
      path -> "DOT written to #{path} — "
    end
  end

  defp print_success(["run" | _]), do: IO.puts("workflow finished")
  defp print_success(["visualize" | _]), do: :ok
  defp print_success(["init" | _]), do: :ok
  defp print_success(_), do: :ok

  defp print_init_summary(created, skipped) do
    Enum.each(created, fn path -> IO.puts("created #{path}") end)
    Enum.each(skipped, fn path -> IO.puts("skipped #{path} (exists)") end)

    if created == [] and skipped == [] do
      IO.puts("no template files found")
    else
      IO.puts("orchestrator workspace initialized")
    end
  end

  defp usage do
    IO.puts(:stderr, """
    Usage:
      orchestrator init [--force]
      orchestrator run </full/path/to/program.yml>
      orchestrator visualize </full/path/to/program.yml> [--format dot|png|svg] [--out <basename>]

    init copies priv templates into .orchestrator/ under the workspace (cwd or ORCHESTRATOR_WORKSPACE).
    Workspace root is inferred from the program path (parent of .orchestrator/).
    Default visualize writes DOT and PNG to .orchestrator/visualizations/.
    Override workspace with ORCHESTRATOR_WORKSPACE if needed.
    """)
  end
end
