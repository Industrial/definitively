defmodule Definitively.MCPServer do
  @moduledoc """
  MCP stdio server exposing definitively workflow tools to Cursor and other hosts.

  Tools delegate to `Definitively.MCP.handle_tool/2`.
  """

  use Hermes.Server,
    name: "definitively",
    version: "0.3.1",
    capabilities: [:tools]

  alias Definitively.MCP
  alias Hermes.MCP.Error
  alias Hermes.Server.Frame
  alias Hermes.Server.Response

  @program_path_schema %{
    program_path: {
      :required,
      :string,
      description: "Path to a definitively program YAML (prefer absolute)"
    },
    workspace_root: {
      :optional,
      :string,
      description: "Workspace root override (default: DEFINITIVELY_WORKSPACE or inferred)"
    },
    run_id: {:optional, :string, description: "Optional run id for coordinator state"}
  }

  @visualize_schema Map.merge(@program_path_schema, %{
                      format: {
                        :optional,
                        :string,
                        description: "Output format: dot (default), png, or svg"
                      },
                      out: {:optional, :string, description: "Output basename (png/svg only)"}
                    })

  @impl true
  def init(_client_info, frame) do
    frame =
      frame
      |> Frame.register_tool("workflow_run",
        description: "Run a definitively YAML program until a final or approval state",
        input_schema: @program_path_schema
      )
      |> Frame.register_tool("workflow_visualize",
        description: "Render a definitively program graph (dot, png, or svg)",
        input_schema: @visualize_schema
      )

    {:ok, frame}
  end

  @impl true
  def handle_tool_call("workflow_run", args, frame) do
    reply(MCP.handle_tool("workflow_run", args), frame)
  end

  def handle_tool_call("workflow_visualize", args, frame) do
    reply(MCP.handle_tool("workflow_visualize", args), frame)
  end

  defp reply({:ok, result}, frame) do
    response = Response.tool() |> Response.json(result)
    {:reply, response, frame}
  end

  defp reply({:error, %{error: %{message: message}}}, frame) when is_binary(message) do
    response = Response.tool() |> Response.error(message)
    {:reply, response, frame}
  end

  defp reply({:error, err}, frame) do
    {:error, Error.execution(Jason.encode!(err, pretty: true)), frame}
  end

  @doc false
  @spec format_tool_reply({:ok, map()} | {:error, map()}, Frame.t()) ::
          {:reply, term(), Frame.t()} | {:error, term(), Frame.t()}
  def format_tool_reply(result, frame), do: reply(result, frame)
end
