defmodule Definitively.Nodes.Gh do
  @moduledoc """
  Runs GitHub CLI nodes with structured actions and parsed outcomes.

  Configure `config :definitively, :gh_runner` as `{Mod, :run, extra_args}` for tests.
  """

  @behaviour Definitively.Nodes.Executor

  alias Definitively.Domain.{GhAction, NodeDefinition, RawResult}
  alias Definitively.Log
  alias Definitively.Nodes.CmdExec
  alias Definitively.Workflow.RunContext

  @impl Definitively.Nodes.Executor
  @spec execute(NodeDefinition.t(), RunContext.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def execute(%NodeDefinition{kind: :gh} = node, %RunContext{} = ctx) do
    cwd = cwd_for(node, ctx)
    timeout_ms = node.timeout_ms || 900_000

    with {:ok, argv} <- GhAction.argv_for(node) do
      Log.debug("gh node execute", node_id: node.id, action: node.action, cwd: cwd)
      invoke(node, ctx, argv, cwd, timeout_ms)
    end
  end

  def execute(%NodeDefinition{kind: kind}, _ctx), do: {:error, {:unsupported_kind, kind}}

  @doc false
  @spec invoke(NodeDefinition.t(), RunContext.t(), term(), Path.t(), pos_integer()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def invoke(node, ctx, argv, cwd, timeout_ms) do
    case Application.get_env(:definitively, :gh_runner) do
      {mod, fun, extra} when is_atom(mod) and is_atom(fun) ->
        apply(mod, fun, [node, ctx, argv, cwd, timeout_ms | List.wrap(extra)])

      _ ->
        run_gh(node, argv, cwd, timeout_ms)
    end
  end

  defp run_gh(node, {:resolve_then_watch, list_args}, cwd, timeout_ms) do
    with {:ok, %RawResult{exit_code: 0, stdout: stdout} = list_raw} <-
           CmdExec.run_argv("gh", list_args, cd: cwd, timeout_ms: timeout_ms),
         {:ok, run_id} <- GhAction.extract_run_id(stdout),
         {:ok, watch_raw} <-
           CmdExec.run_argv("gh", ["run", "watch", run_id, "--exit-status"],
             cd: cwd,
             timeout_ms: timeout_ms
           ) do
      {:ok, enrich(node, merge_stdout(list_raw, watch_raw))}
    else
      {:ok, raw} -> {:ok, enrich(node, raw)}
      {:error, _} = err -> err
    end
  end

  defp run_gh(node, argv, cwd, timeout_ms) do
    case CmdExec.run_argv("gh", argv, cd: cwd, timeout_ms: timeout_ms) do
      {:ok, raw} -> {:ok, enrich(node, raw)}
      {:error, _} = err -> err
    end
  end

  defp enrich(_node, %RawResult{timed_out: true} = raw), do: raw

  defp enrich(node, %RawResult{} = raw) do
    {signals, data} = GhAction.parse_result(node.action, raw.exit_code || 1, raw.stdout)

    %{raw | signals: Map.merge(raw.signals, signals), data: data}
  end

  defp merge_stdout(%RawResult{stdout: a} = left, %RawResult{stdout: b}) do
    %{left | stdout: a <> "\n" <> b}
  end

  defp cwd_for(%NodeDefinition{cwd: nil}, ctx), do: ctx.workspace_root

  defp cwd_for(%NodeDefinition{cwd: cwd}, ctx) do
    Path.expand(cwd, ctx.workspace_root)
  end
end
