defmodule Definitively.MCP.Serve do
  @moduledoc """
  Boots the Hermes MCP stdio transport for IDE hosts (Cursor, Claude Desktop, etc.).

  Logs go to stderr only; stdout is reserved for the MCP JSON-RPC stream.
  """

  @doc """
  Starts `Definitively.MCPServer` with stdio transport and blocks until the process exits.
  """
  @spec run() :: no_return()
  def run do
    configure_stdio_logging!()

    children = [
      Hermes.Server.Registry,
      {Definitively.MCPServer, transport: :stdio}
    ]

    case Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            IO.puts(:stderr, "definitively mcp serve stopped: #{inspect(reason)}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts(:stderr, "definitively mcp serve failed to start: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp configure_stdio_logging! do
    level =
      System.get_env("DEFINITIVELY_LOG_LEVEL", "WARN")
      |> String.trim()
      |> String.downcase()
      |> case do
        "trace" -> :debug
        "debug" -> :debug
        "info" -> :info
        "warn" -> :warning
        "warning" -> :warning
        "error" -> :error
        _ -> :warning
      end

    Logger.configure(level: level)
    :ok
  end
end
