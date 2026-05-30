defmodule Orchestrator.MCP do

  alias Orchestrator.Log
  @moduledoc """
  MCP-style tool surface over `Orchestrator.Run.Coordinator`.

  Tools: `workflow_run`, `workflow_status`, `workflow_approve`, `workflow_cancel`.
  Returns JSON-friendly maps for stdio or HTTP transports.
  """

  alias Orchestrator.Run.{Coordinator, Snapshot}

  @tools ~w(workflow_run workflow_status workflow_approve workflow_cancel)

  @doc "Lists supported tool names."
  @spec tools() :: [String.t()]
  def tools, do: @tools

  @doc "Dispatches a tool call by name and parameter map."
  @spec handle_tool(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def handle_tool(name, params) when is_map(params) do
    case name do
      "workflow_run" -> tool_run(params)
      "workflow_status" -> tool_status(params)
      "workflow_approve" -> tool_approve(params)
      "workflow_cancel" -> tool_cancel(params)
      _ -> {:error, error_map(:unknown_tool, "unknown tool #{inspect(name)}")}
    end
  end

  defp tool_run(%{"program_path" => path} = params) do
    Log.info("mcp workflow_run", program_path: path)
    opts = run_opts(params)

    if truthy?(Map.get(params, "auto_run", true)) do
      case Coordinator.run_until_final(path, opts) do
        :ok ->
          {:ok, %{ok: true, result: "finished"}}

        {:error, :awaiting_approval} ->
          {:ok, %{ok: false, awaiting_approval: true}}

        {:error, reason} ->
          {:error, error_map(:run_failed, reason)}
      end
    else
      case Coordinator.start(path, opts) do
        {:ok, run_id} ->
          {:ok, %{ok: true, run_id: run_id}}

        {:error, reason} ->
          {:error, error_map(:start_failed, reason)}
      end
    end
  end

  defp tool_run(_), do: {:error, error_map(:invalid_params, "program_path required")}

  defp tool_status(%{"run_id" => run_id}) do
    case Coordinator.status(run_id) do
      {:ok, %Snapshot{} = snap} -> {:ok, snapshot_map(snap)}
      {:error, reason} -> {:error, error_map(:status_failed, reason)}
    end
  end

  defp tool_status(_), do: {:error, error_map(:invalid_params, "run_id required")}

  defp tool_approve(%{"run_id" => run_id, "label" => label}) do
    with {:ok, label_atom} <- safe_label(label),
         :ok <- Coordinator.approve(run_id, label_atom),
         :ok <- Coordinator.resume(run_id) do
      {:ok, %{ok: true, run_id: run_id, label: label}}
    else
      {:error, reason} -> {:error, error_map(:approve_failed, reason)}
    end
  end

  defp tool_approve(_),
    do: {:error, error_map(:invalid_params, "run_id and label required")}

  defp tool_cancel(%{"run_id" => run_id}) do
    case Coordinator.cancel(run_id) do
      :ok -> {:ok, %{ok: true, run_id: run_id}}
      {:error, reason} -> {:error, error_map(:cancel_failed, reason)}
    end
  end

  defp tool_cancel(_), do: {:error, error_map(:invalid_params, "run_id required")}

  defp snapshot_map(%Snapshot{} = snap) do
    %{
      run_id: snap.run_id,
      program_id: snap.program_id,
      current_state: snap.current_state,
      state_type: snap.state_type,
      approval_prompt: snap.approval_prompt,
      done: snap.done,
      history: snap.history
    }
  end

  defp run_opts(params) do
    []
    |> maybe_put(:workspace_root, Map.get(params, "workspace_root"))
    |> maybe_put(:run_id, Map.get(params, "run_id"))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, val), do: Keyword.put(opts, key, val)

  defp safe_label(label) do
    {:ok, String.to_existing_atom(label)}
  rescue
    ArgumentError -> {:error, :invalid_label}
  end

  defp truthy?(val) when val in [true, "true", 1, "1"], do: true
  defp truthy?(_), do: false

  defp error_map(code, message) do
    %{ok: false, error: %{code: code, message: format_message(message)}}
  end

  defp format_message(msg) when is_binary(msg), do: msg
  defp format_message(msg), do: inspect(msg, pretty: true, limit: :infinity)
end
