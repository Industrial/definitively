defmodule Definitively.Nodes.StreamCmd do

  alias Definitively.Log
  @moduledoc """
  Runs a subprocess with stdout/stderr streamed to the terminal and captured for callers.
  """

  @doc "Runs `executable` with `args`, streaming output until exit or timeout."
  @spec run(Path.t(), [String.t()], keyword()) ::
          {:ok, {String.t(), non_neg_integer(), non_neg_integer()}}
          | {:ok, {:timed_out, String.t(), non_neg_integer()}}
  def run(executable, args, opts) do
    cwd = Keyword.fetch!(opts, :cd)
    timeout_ms = Keyword.get(opts, :timeout_ms, 120_000)
    env = Keyword.get(opts, :env)
    started = System.monotonic_time(:millisecond)

    exe = resolve_executable(executable)
    cmd = Enum.join([executable | args], " ")

    Log.debug("subprocess starting",
      executable: exe,
      command: cmd,
      cwd: cwd,
      timeout_ms: timeout_ms
    )

    port_opts =
      [
        :binary,
        :exit_status,
        {:args, Enum.map(args, &String.to_charlist/1)},
        {:cd, String.to_charlist(cwd)},
        :stderr_to_stdout
      ] ++ env_opt(env)

    port =
      Port.open(
        {:spawn_executable, String.to_charlist(exe)},
        port_opts
      )

    collect(port, timeout_ms, "", started)
  end

  @doc false
  @spec resolve_executable(String.t()) :: String.t()
  def resolve_executable(name) do
    System.find_executable(name) || name
  end

  defp env_opt(nil), do: []

  defp env_opt(charlist_env) when is_list(charlist_env) do
    [{:env, [~c"LANGUAGE=en_US.UTF-8", ~c"LC_ALL=en_US.UTF-8" | charlist_env]}]
  end

  defp maybe_write_stdio(chunk) do
    if Application.get_env(:definitively, :stream_output, true) do
      IO.write(:stdio, chunk)
    end
  end

  defp collect(port, timeout_ms, acc, started) do
    receive do
      {^port, {:data, chunk}} ->
        maybe_write_stdio(chunk)
        Log.trace("subprocess output", bytes: byte_size(chunk))
        collect(port, timeout_ms, acc <> chunk, started)

      {^port, {:exit_status, status}} ->
        ended = System.monotonic_time(:millisecond)
        duration = ended - started

        Log.debug("subprocess finished",
          exit_code: status,
          duration_ms: duration,
          stdout_bytes: byte_size(acc)
        )

        {:ok, {acc, status, duration}}
    after
      timeout_ms ->
        close_port(port)
        ended = System.monotonic_time(:millisecond)
        duration = ended - started
        Log.warn("subprocess timed out", duration_ms: duration, stdout_bytes: byte_size(acc))
        {:ok, {:timed_out, acc, duration}}
    end
  end

  defp close_port(port) do
    Port.close(port)
    drain_port(port)
  end

  defp drain_port(port) do
    receive do
      {^port, _} -> drain_port(port)
    after
      0 -> :ok
    end
  end
end
