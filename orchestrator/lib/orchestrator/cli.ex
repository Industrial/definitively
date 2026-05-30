defmodule Orchestrator.CLI do
  @moduledoc "Command-line interface for workflow runs."

  alias Orchestrator.Run.Coordinator

  @doc "Entry point for `mix orchestrator`."
  @spec main([String.t()]) :: :ok | no_return()
  def main(argv \\ []) do
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
    case Coordinator.run_until_final(program_path) do
      :ok -> :ok
      {:error, :awaiting_approval} -> {:error, :awaiting_approval, 2}
      {:error, reason} -> {:error, reason, 1}
    end
  end

  defp dispatch_status(run_id) do
    case Coordinator.status(run_id) do
      {:ok, _snap} -> :ok
      {:error, reason} -> {:error, reason, 1}
    end
  end

  defp dispatch_approve(run_id, label) do
    with {:ok, label_atom} <- safe_label(label),
         :ok <- Coordinator.approve(run_id, label_atom),
         :ok <- Coordinator.resume(run_id) do
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

  defp format_error(:awaiting_approval),
    do: "workflow awaiting approval — use orchestrator approve"

  defp format_error(reason), do: "workflow failed: #{inspect(reason)}"

  defp print_success(["run" | _]), do: IO.puts("workflow finished")
  defp print_success(["approve" | _]), do: IO.puts("approved")
  defp print_success(["cancel" | _]), do: IO.puts("cancelled")
  defp print_success(_), do: :ok

  defp usage do
    IO.puts(:stderr, """
    Usage:
      mix orchestrator run <program.yml>
      mix orchestrator status <run-id>
      mix orchestrator approve <run-id> <label>
      mix orchestrator cancel <run-id>
    """)
  end
end
