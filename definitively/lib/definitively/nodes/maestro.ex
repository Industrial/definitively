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

        attrs = %{
          "spec_path" => ".maestro/specs/#{slug}.md",
          "decompose_file" => ".definitively/state/#{slug}-decompose.json"
        }

        RunState.put(cwd, attrs)
        RunState.seal(cwd, Map.merge(%{"plan_file" => state["plan_file"]}, attrs))

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
            {stdout, exit_code} = maybe_recover_mission_from_spec(node, raw, cwd)

            {signals, data} =
              MaestroAction.parse_result(node.action, exit_code, stdout, cwd)

            exit_code = effective_exit_code(exit_code, signals)

            {:ok,
             %{
               raw
               | stdout: stdout,
                 exit_code: exit_code,
                 signals: Map.merge(raw.signals, signals),
                 data: data
             }}
        end
    end
  end

  defp maybe_recover_mission_from_spec(%NodeDefinition{action: :mission_from_spec}, raw, cwd) do
    case MaestroAction.recover_existing_mission(raw.stdout || "", cwd) do
      {:ok, _mission_id, synthetic_stdout} when raw.exit_code != 0 ->
        Log.info("reusing existing maestro mission", prior_exit_code: raw.exit_code)

        {synthetic_stdout, 0}

      _ ->
        {raw.stdout || "", raw.exit_code || 1}
    end
  end

  defp maybe_recover_mission_from_spec(_node, raw, _cwd), do: {raw.stdout || "", raw.exit_code || 1}

  defp effective_exit_code(exit_code, signals) do
    parse_failed? =
      Map.get(signals, :parse_failed) == true or Map.get(signals, "parse_failed") == true

    if parse_failed?, do: 1, else: exit_code || 0
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
