defmodule Definitively.Nodes.Git do
  @moduledoc "Runs git nodes with structured actions and parsed outcomes."

  @behaviour Definitively.Nodes.Executor

  alias Definitively.Domain.{GitAction, NodeDefinition, RawResult}
  alias Definitively.Log
  alias Definitively.Nodes.CmdExec
  alias Definitively.Workflow.RunContext

  @impl Definitively.Nodes.Executor
  @spec execute(NodeDefinition.t(), RunContext.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def execute(%NodeDefinition{kind: :git} = node, %RunContext{} = ctx) do
    cwd = cwd_for(node, ctx)
    timeout_ms = node.timeout_ms || 120_000

    with {:ok, argv} <- GitAction.argv_for(node) do
      Log.debug("git node execute", node_id: node.id, action: node.action, cwd: cwd)

      case CmdExec.run_argv("git", argv, cd: cwd, timeout_ms: timeout_ms) do
        {:ok, {:timed_out, raw}} ->
          {:ok, raw}

        {:ok, %RawResult{} = raw} ->
          {signals, data} = GitAction.parse_result(node.action, raw.exit_code || 1, raw.stdout)
          {:ok, %{raw | signals: Map.merge(raw.signals, signals), data: data}}
      end
    end
  end

  def execute(%NodeDefinition{kind: kind}, _ctx), do: {:error, {:unsupported_kind, kind}}

  defp cwd_for(%NodeDefinition{cwd: nil}, ctx), do: ctx.workspace_root

  defp cwd_for(%NodeDefinition{cwd: cwd}, ctx) do
    Path.expand(cwd, ctx.workspace_root)
  end
end
