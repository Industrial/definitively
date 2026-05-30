defmodule Orchestrator.Nodes.Cli do
  @moduledoc "Runs CLI nodes with live stdout/stderr streaming and captured output."

  @behaviour Orchestrator.Nodes.Executor

  alias Orchestrator.Domain.{NodeDefinition, RawResult}
  alias Orchestrator.Log
  alias Orchestrator.Nodes.StreamCmd
  alias Orchestrator.Workflow.RunContext

  @impl Orchestrator.Nodes.Executor
  @spec execute(NodeDefinition.t(), RunContext.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def execute(%NodeDefinition{kind: :cli} = node, %RunContext{} = ctx) do
    command = node.command || []
    cwd = cwd_for(node, ctx)
    timeout_ms = node.timeout_ms || 120_000

    [executable | args] = with_run_env(command, ctx.env)

    Log.debug("cli node execute",
      node_id: node.id,
      command: Enum.join(command, " "),
      cwd: cwd
    )

    case StreamCmd.run(executable, args, cd: cwd, timeout_ms: timeout_ms) do
      {:ok, {:timed_out, _output, duration_ms}} ->
        {:ok, %RawResult{timed_out: true, duration_ms: duration_ms}}

      {:ok, {output, exit_code, duration_ms}} ->
        {:ok,
         %RawResult{
           exit_code: exit_code,
           stdout: output,
           stderr: "",
           duration_ms: duration_ms,
           timed_out: false
         }}
    end
  end

  def execute(%NodeDefinition{kind: kind}, _ctx), do: {:error, {:unsupported_kind, kind}}

  defp cwd_for(%NodeDefinition{cwd: nil}, ctx), do: ctx.workspace_root

  defp cwd_for(%NodeDefinition{cwd: cwd}, ctx) do
    Path.expand(cwd, ctx.workspace_root)
  end

  defp with_run_env(command, env) when env in [nil, %{}], do: command

  defp with_run_env(command, env) when is_map(env) do
    assignments = Enum.map(env, fn {k, v} -> "#{k}=#{v}" end)
    ["env" | assignments ++ command]
  end
end
