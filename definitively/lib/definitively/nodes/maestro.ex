defmodule Definitively.Nodes.Maestro do
  @moduledoc """
  Runs Maestro harness CLI nodes with structured actions and parsed outcomes.

  Configure `config :definitively, :maestro_runner` as `{Mod, :run, extra_args}` for tests.
  """

  @behaviour Definitively.Nodes.Executor

  alias Definitively.Domain.{MaestroAction, NodeDefinition, RawResult}
  alias Definitively.Log
  alias Definitively.Maestro.RunState
  alias Definitively.Nodes.CmdExec
  alias Definitively.Workflow.RunContext

  @impl Definitively.Nodes.Executor
  @spec execute(NodeDefinition.t(), RunContext.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def execute(%NodeDefinition{kind: :maestro} = node, %RunContext{} = ctx) do
    cwd = ctx.workspace_root
    timeout_ms = node.timeout_ms || 600_000

    with {:ok, argv} <- MaestroAction.argv_for(node, cwd) do
      Log.debug("maestro node execute", node_id: node.id, action: node.action, cwd: cwd)
      invoke(node, ctx, argv, cwd, timeout_ms)
    end
  end

  def execute(%NodeDefinition{kind: kind}, _ctx), do: {:error, {:unsupported_kind, kind}}

  @doc false
  @spec invoke(NodeDefinition.t(), RunContext.t(), term(), Path.t(), pos_integer()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def invoke(node, ctx, argv, cwd, timeout_ms) do
    case Application.get_env(:definitively, :maestro_runner) do
      {mod, fun, extra} when is_atom(mod) and is_atom(fun) ->
        apply(mod, fun, [node, ctx, argv, cwd, timeout_ms | List.wrap(extra)])

      _ ->
        run_maestro(node, argv, cwd, timeout_ms)
    end
  end

  defp run_maestro(%NodeDefinition{action: :init_run} = node, :init_run, cwd, _timeout_ms) do
    case RunState.init_plan(cwd, node.options || %{}) do
      :ok ->
        state = RunState.load(cwd)
        slug = slug_from_plan(state["plan_file"])

        RunState.put(cwd, %{
          "spec_path" => ".maestro/specs/#{slug}.md",
          "decompose_file" => ".definitively/state/#{slug}-decompose.json"
        })

        {:ok, %RawResult{exit_code: 0, stdout: "", data: RunState.load(cwd)}}

      {:error, _} = err ->
        err
    end
  end

  defp run_maestro(_node, {:claim_next, mission_id}, cwd, timeout_ms) do
    runner = fn exe, args, opts ->
      case CmdExec.run_argv(exe, args, opts) do
        {:ok, {:timed_out, raw}} -> {:ok, raw}
        {:ok, raw} -> {:ok, raw}
        {:error, _} = err -> err
      end
    end

    case MaestroAction.run_claim_next(mission_id, cwd, runner) do
      {:ok, {code, stdout, signals, data}} ->
        {:ok,
         %RawResult{
           exit_code: code,
           stdout: stdout,
           duration_ms: timeout_ms,
           timed_out: false,
           signals: signals,
           data: data
         }}

      {:error, _} = err ->
        err
    end
  end

  defp run_maestro(node, argv, cwd, timeout_ms) when is_list(argv) do
    case argv do
      [] ->
        {:ok, %RawResult{exit_code: 0, stdout: ""}}

      _ ->
        case CmdExec.run_argv("maestro", argv, cd: cwd, timeout_ms: timeout_ms) do
          {:ok, {:timed_out, raw}} ->
            {:ok, raw}

          {:ok, %RawResult{} = raw} ->
            {signals, data} =
              MaestroAction.parse_result(node.action, raw.exit_code || 1, raw.stdout, cwd)

            {:ok, %{raw | signals: Map.merge(raw.signals, signals), data: data}}
        end
    end
  end

  defp slug_from_plan(plan_file) do
    plan_file
    |> Path.basename()
    |> String.replace_suffix(".plan.md", "")
    |> String.replace_suffix(".md", "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
