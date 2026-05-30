defmodule Orchestrator.Nodes.Cli do
  @moduledoc "Runs CLI nodes via `System.cmd` with timeout and captured streams."

  @behaviour Orchestrator.Nodes.Executor

  alias Orchestrator.Domain.{NodeDefinition, RawResult}
  alias Orchestrator.Workflow.RunContext

  @impl Orchestrator.Nodes.Executor
  @spec execute(NodeDefinition.t(), RunContext.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def execute(%NodeDefinition{kind: :cli} = node, %RunContext{} = ctx) do
    command = node.command || []
    cwd = cwd_for(node, ctx)
    timeout_ms = node.timeout_ms || 120_000
    env = cmd_env(ctx.env)

    started = System.monotonic_time(:millisecond)

    [executable | args] = command

    task =
      Task.async(fn ->
        executable
        |> System.cmd(args, cmd_opts(cwd, env))
      end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, exit_code}} ->
        ended = System.monotonic_time(:millisecond)

        {:ok,
         %RawResult{
           exit_code: exit_code,
           stdout: output,
           stderr: "",
           duration_ms: ended - started,
           timed_out: false
         }}

      nil ->
        {:ok,
         %RawResult{
           timed_out: true,
           duration_ms: timeout_ms
         }}

      {:exit, reason} ->
        {:error, reason}
    end
  end

  def execute(%NodeDefinition{kind: kind}, _ctx), do: {:error, {:unsupported_kind, kind}}

  defp cwd_for(%NodeDefinition{cwd: nil}, ctx), do: ctx.workspace_root

  defp cwd_for(%NodeDefinition{cwd: cwd}, ctx) do
    Path.expand(cwd, ctx.workspace_root)
  end

  defp cmd_opts(cwd, env) do
    base = [cd: cwd, stderr_to_stdout: false]

    case env do
      nil -> base
      charlist_env -> Keyword.put(base, :env, charlist_env)
    end
  end

  defp cmd_env(env) when env == %{}, do: nil

  defp cmd_env(env) when is_map(env) do
    Enum.map(env, fn {k, v} ->
      {String.to_charlist(to_string(k)), String.to_charlist(to_string(v))}
    end)
  end
end
