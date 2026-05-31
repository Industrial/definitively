defmodule Definitively.MCPServerTest do
  use ExUnit.Case, async: true

  alias Definitively.MCP
  alias Definitively.MCPServer
  alias Hermes.Server.Frame
  alias Hermes.Server.Response

  @echo Path.expand("../fixtures/echo_ok.yml", __DIR__)

  test "init registers workflow tools" do
    assert {:ok, frame} = MCPServer.init(%{}, Frame.new())

    tool_names =
      frame
      |> Frame.get_tools()
      |> Enum.map(& &1.name)
      |> Enum.sort()

    assert tool_names == MCP.tools()
  end

  test "handle_tool_call workflow_run echoes MCP handler" do
    frame = Frame.new()

    assert {:reply, response, _} =
             MCPServer.handle_tool_call(
               "workflow_run",
               %{"program_path" => @echo},
               frame
             )

    assert %{"content" => [%{"type" => "text", "text" => text}], "isError" => false} =
             Response.to_protocol(response)

    assert Jason.decode!(text) == %{"ok" => true, "result" => "finished"}
  end
end
