defmodule Orchestrator.Nodes.Llm do
  @moduledoc """
  Runs LLM nodes by invoking a configurable runner and parsing a JSON envelope.

  Configure `config :orchestrator, :llm_runner` as `{Mod, :fun, extra_args}` for
  tests; default runs a shell command from `:llm_command` env or built-in stub.
  """

  @behaviour Orchestrator.Nodes.Executor

  alias Orchestrator.Domain.{NodeDefinition, RawResult}
  alias Orchestrator.Workflow.RunContext

  @impl Orchestrator.Nodes.Executor
  @spec execute(NodeDefinition.t(), RunContext.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def execute(%NodeDefinition{kind: :llm} = node, %RunContext{} = ctx) do
    with {:ok, prompt} <- read_prompt(node, ctx),
         {:ok, raw} <- invoke_runner(node, ctx, prompt) do
      {:ok, enrich_raw(raw)}
    end
  end

  def execute(%NodeDefinition{kind: kind}, _ctx), do: {:error, {:unsupported_kind, kind}}

  @doc false
  @spec invoke_runner(NodeDefinition.t(), RunContext.t(), String.t()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def invoke_runner(node, ctx, prompt) do
    case Application.get_env(:orchestrator, :llm_runner) do
      {mod, fun, extra} when is_atom(mod) and is_atom(fun) ->
        apply(mod, fun, [node, ctx, prompt | List.wrap(extra)])

      _ ->
        run_command(node, ctx, prompt)
    end
  end

  @doc false
  @spec read_prompt(NodeDefinition.t(), RunContext.t()) ::
          {:ok, String.t()} | {:error, term()}
  def read_prompt(%NodeDefinition{prompt_file: nil}, _ctx),
    do: {:error, :missing_prompt_file}

  def read_prompt(%NodeDefinition{prompt_file: path}, %RunContext{workspace_root: root}) do
    full = Path.expand(path, root)

    case File.read(full) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, {:prompt_read_failed, reason}}
    end
  end

  defp run_command(node, ctx, prompt) do
    started = System.monotonic_time(:millisecond)
    command = llm_command()
    timeout_ms = node.timeout_ms || 600_000
    payload = Jason.encode!(%{model: node.model, prompt: prompt, run_id: ctx.run_id})

    task =
      Task.async(fn ->
        [exe | args] = command
        System.cmd(exe, args ++ [payload], cd: ctx.workspace_root)
      end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} ->
        ended = System.monotonic_time(:millisecond)
        parse_json_output(output, ended - started)

      {:ok, {_output, code}} ->
        {:ok, %RawResult{exit_code: code, timed_out: false}}

      nil ->
        {:ok, %RawResult{timed_out: true, duration_ms: timeout_ms}}

      {:exit, reason} ->
        {:error, reason}
    end
  end

  defp parse_json_output(output, duration_ms) do
    case Jason.decode(output) do
      {:ok, map} when is_map(map) ->
        {:ok,
         %RawResult{
           exit_code: 0,
           stdout: output,
           duration_ms: duration_ms,
           llm_json: map,
           signals: Map.get(map, "signals", %{})
         }}

      _ ->
        {:ok,
         %RawResult{
           exit_code: 0,
           stdout: output,
           duration_ms: duration_ms,
           llm_json: %{"status" => "ok", "raw" => output}
         }}
    end
  end

  defp enrich_raw(%RawResult{llm_json: %{} = json} = raw) do
    signals =
      json
      |> Map.get("signals", %{})
      |> normalize_signals()

    %{raw | signals: Map.merge(raw.signals, signals)}
  end

  defp enrich_raw(raw), do: raw

  defp normalize_signals(signals) when is_map(signals), do: signals
  defp normalize_signals(_), do: %{}

  defp llm_command do
    case System.get_env("ORCHESTRATOR_LLM_COMMAND") do
      nil ->
        [
          "sh",
          "-c",
          "cat >/dev/null; printf '%s' '{\"status\":\"ok\",\"signals\":{\"fix_complete\":true}}'"
        ]

      line ->
        String.split(line, " ", trim: true)
    end
  end
end
