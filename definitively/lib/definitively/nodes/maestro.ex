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
        case apply(mod, fun, [node, ctx, argv, cwd, timeout_ms | List.wrap(extra)]) do
          {:ok, %RawResult{} = raw} when is_list(argv) ->
            {:ok, finalize_maestro_raw(node, raw, cwd)}

          other ->
            other
        end

      _ ->
        run_maestro(node, ctx, argv, cwd, timeout_ms)
    end
  end

  defp run_maestro(_node, ctx, :init_run, cwd, _timeout_ms) do
    case RunState.init_plan(cwd, %{"inputs" => ctx.inputs}) do
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

  defp run_maestro(_node, _ctx, {:claim_next, mission_id}, cwd, timeout_ms) do
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

  defp run_maestro(node, _ctx, argv, cwd, timeout_ms) when is_list(argv) do
    case argv do
      [] ->
        {:ok, %RawResult{exit_code: 0, stdout: ""}}

      _ ->
        case CmdExec.run_argv("maestro", argv, cd: cwd, timeout_ms: timeout_ms) do
          {:ok, {:timed_out, raw}} ->
            {:ok, raw}

          {:ok, %RawResult{} = raw} ->
            {:ok, finalize_maestro_raw(node, raw, cwd)}
        end
    end
  end

  defp finalize_maestro_raw(node, raw, cwd) do
    {stdout, exit_code} = maybe_recover_mission_from_spec(node, raw, cwd)

    {signals, data} =
      MaestroAction.parse_result(node.action, exit_code, stdout, cwd)

    exit_code = effective_exit_code(exit_code, signals)

    %{
      raw
      | stdout: stdout,
        exit_code: exit_code,
        signals: Map.merge(raw.signals, signals),
        data: data
    }
  end

  defp maybe_recover_mission_from_spec(%NodeDefinition{action: :mission_from_spec}, raw, cwd) do
    output = combine_output(raw)

    case MaestroAction.recover_existing_mission(output, cwd) do
      {:ok, _mission_id, synthetic_stdout} when raw.exit_code != 0 ->
        Log.info("reusing existing maestro mission", prior_exit_code: raw.exit_code)

        {synthetic_stdout, 0}

      _ ->
        {raw.stdout || "", raw.exit_code || 1}
    end
  end

  defp maybe_recover_mission_from_spec(%NodeDefinition{action: :mission_decompose}, raw, _cwd) do
    output = combine_output(raw)

    if raw.exit_code != 0 and already_decomposed?(output) do
      Log.info("mission already decomposed; continuing wave loop", prior_exit_code: raw.exit_code)
      {output, 0}
    else
      {raw.stdout || "", raw.exit_code || 1}
    end
  end

  defp maybe_recover_mission_from_spec(_node, raw, _cwd),
    do: {raw.stdout || "", raw.exit_code || 1}

  defp already_decomposed?(output) do
    String.contains?(output, "Invalid mission transition in-progress -> planned")
  end

  defp combine_output(%{stdout: stdout, stderr: stderr}) do
    [stdout, stderr]
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

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
