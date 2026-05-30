defmodule Orchestrator.MCP do
  @moduledoc """
  MCP-style tool surface over `Orchestrator.Run.Coordinator` and `Orchestrator.Visualize`.

  Tools: `workflow_run`, `workflow_visualize`.
  """

  alias Orchestrator.Log
  alias Orchestrator.Run.Coordinator
  alias Orchestrator.Visualize

  @tools ~w(workflow_run workflow_visualize)

  @doc "Lists supported tool names."
  @spec tools() :: [String.t()]
  def tools, do: @tools

  @doc "Dispatches a tool call by name and parameter map."
  @spec handle_tool(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def handle_tool(name, params) when is_map(params) do
    case name do
      "workflow_run" -> tool_run(params)
      "workflow_visualize" -> tool_visualize(params)
      _ -> {:error, error_map(:unknown_tool, "unknown tool #{inspect(name)}")}
    end
  end

  defp tool_run(%{"program_path" => path} = params) do
    Log.info("mcp workflow_run", program_path: path)
    opts = run_opts(params)

    case Coordinator.run_until_final(path, opts) do
      :ok ->
        {:ok, %{ok: true, result: "finished"}}

      {:error, :awaiting_approval} ->
        {:ok, %{ok: false, awaiting_approval: true}}

      {:error, reason} ->
        {:error, error_map(:run_failed, reason)}
    end
  end

  defp tool_run(_), do: {:error, error_map(:invalid_params, "program_path required")}

  defp tool_visualize(%{"program_path" => path} = params) do
    format = parse_format(Map.get(params, "format", "dot"))
    out = Map.get(params, "out")

    case Visualize.render(path, format: format, out: out) do
      {:ok, content} when format == :dot ->
        {:ok, %{ok: true, format: "dot", dot: content}}

      {:ok, file} ->
        {:ok, %{ok: true, format: Atom.to_string(format), path: file}}

      {:error, reason} ->
        {:error, error_map(:visualize_failed, reason)}
    end
  end

  defp tool_visualize(_),
    do: {:error, error_map(:invalid_params, "program_path required")}

  defp parse_format("dot"), do: :dot
  defp parse_format("png"), do: :png
  defp parse_format("svg"), do: :svg
  defp parse_format(_), do: :dot

  defp run_opts(params) do
    []
    |> maybe_put(:workspace_root, Map.get(params, "workspace_root"))
    |> maybe_put(:run_id, Map.get(params, "run_id"))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, val), do: Keyword.put(opts, key, val)

  defp error_map(code, message) do
    %{ok: false, error: %{code: code, message: format_message(message)}}
  end

  defp format_message(msg) when is_binary(msg), do: msg
  defp format_message(msg), do: inspect(msg, pretty: true, limit: :infinity)
end
