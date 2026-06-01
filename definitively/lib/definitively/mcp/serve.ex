defmodule Definitively.MCP.Serve do
  @moduledoc """
  Boots the Hermes MCP stdio transport for IDE hosts (Cursor, Claude Desktop, etc.).

  Logs go to stderr only; stdout is reserved for the MCP JSON-RPC stream.
  """

  @doc false
  @spec log_level_from_env(String.t() | nil) :: Logger.level()
  def log_level_from_env(env \\ nil) do
    (env || System.get_env("DEFINITIVELY_LOG_LEVEL", "WARN"))
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
  end

  @doc false
  @spec configure_logging!() :: :ok
  def configure_logging! do
    Logger.configure(level: log_level_from_env())
    :ok
  end

  @doc false
  @spec start_stdio_supervisor() :: Supervisor.on_start()
  def start_stdio_supervisor do
    children = [
      Hermes.Server.Registry,
      {Definitively.MCPServer, transport: :stdio}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end

  @doc false
  @spec await_supervisor(pid()) :: term()
  def await_supervisor(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> reason
    end
  end

  @doc false
  @spec run_body(Supervisor.on_start()) :: {:halt, String.t()}
  def run_body(start_result) do
    configure_logging!()

    case start_result do
      {:ok, pid} ->
        {:halt, "definitively mcp serve stopped: #{inspect(await_supervisor(pid))}"}

      {:error, reason} ->
        {:halt, "definitively mcp serve failed to start: #{inspect(reason)}"}
    end
  end

  @doc """
  Starts `Definitively.MCPServer` with stdio transport and blocks until the process exits.
  """
  @spec run() :: no_return()
  def run do
    case run_body(start_stdio_supervisor()) do
      {:halt, message} ->
        IO.puts(:stderr, message)
        System.halt(1)
    end
  end

end
