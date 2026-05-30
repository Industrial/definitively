defmodule Orchestrator.CLI do
  @moduledoc "Command-line interface for workflow runs."

  alias Orchestrator.Log
  alias Orchestrator.Run.Coordinator
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

      ["status", run_id] ->
        dispatch_status(run_id)

      ["approve", run_id, label] ->
        dispatch_approve(run_id, label)

      ["cancel", run_id] ->
        dispatch_cancel(run_id)

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

  defp start_and_resume(program_path, opts) do
    case Coordinator.start(program_path, opts) do
      {:ok, run_id} ->
        case Coordinator.resume(run_id, opts) do
          :ok ->
            Log.info("workflow completed", run_id: run_id)
            :ok

          {:error, :awaiting_approval} ->
            IO.puts(:stderr, "run_id=#{run_id}")
            IO.puts(:stderr, "approve: orchestrator approve #{run_id} approve")
            {:error, :awaiting_approval, 2}

          {:error, reason} ->
            Log.error("workflow failed", run_id: run_id, error: inspect(reason))
            {:error, reason, 1}
        end

      {:error, reason} ->
        {:error, reason, 1}
    end
  end

  defp dispatch_status(run_id) do
    case Coordinator.status(run_id) do
      {:ok, _snap} -> :ok
      {:error, reason} -> {:error, reason, 1}
    end
  end

  defp run_opts(%{workspace_root: discovered}) do
    root = System.get_env("ORCHESTRATOR_WORKSPACE", discovered)
    [workspace_root: root]
  end

  defp dispatch_approve(run_id, label) do
    with {:ok, label_atom} <- safe_label(label),
         :ok <- Coordinator.approve(run_id, label_atom),
         :ok <- Coordinator.resume(run_id, approve_opts()) do
      :ok
    else
      {:error, reason} -> {:error, reason, 1}
    end
  end

  defp dispatch_cancel(run_id) do
    case Coordinator.cancel(run_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason, 1}
    end
  end

  defp safe_label(label) do
    {:ok, String.to_existing_atom(label)}
  rescue
    ArgumentError -> {:error, :invalid_label}
  end

  defp approve_opts do
    case System.get_env("ORCHESTRATOR_WORKSPACE") do
      nil -> []
      root -> [workspace_root: root]
    end
  end

  defp format_error(:invalid_program_path),
    do: "program file not found — pass the full path to a .yml file"

  defp format_error(:no_orchestrator_layout),
    do: "program must live under a .orchestrator/ directory (workspace root is its parent)"

  defp format_error(:awaiting_approval),
    do: "workflow awaiting approval — use: orchestrator approve <run-id> <label>"

  defp format_error(reason), do: "workflow failed: #{inspect(reason)}"

  defp print_success(["run" | _]), do: IO.puts("workflow finished")
  defp print_success(["approve" | _]), do: IO.puts("approved")
  defp print_success(["cancel" | _]), do: IO.puts("cancelled")
  defp print_success(_), do: :ok

  defp usage do
    IO.puts(:stderr, """
    Usage:
      orchestrator run </full/path/to/program.yml>
      orchestrator status <run-id>
      orchestrator approve <run-id> <label>
      orchestrator cancel <run-id>

    Workspace root is inferred from the program path (parent of .orchestrator/).
    Override with ORCHESTRATOR_WORKSPACE if needed.
    """)
  end
end
