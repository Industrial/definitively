defmodule Definitively.Nodes.Llm do
  @moduledoc """
  Runs LLM nodes by invoking a configurable runner and parsing a JSON envelope.

  Configure `config :definitively, :llm_runner` as `{Mod, :fun, extra_args}` for
  tests; default runs a shell command from the node's `command` list or env stub.
  """

  @behaviour Definitively.Nodes.Executor

  alias Definitively.Domain.{NodeDefinition, RawResult}
  alias Definitively.Log
  alias Definitively.Nodes.StreamCmd
  alias Definitively.Workflow.RunContext

  @impl Definitively.Nodes.Executor
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
    case Application.get_env(:definitively, :llm_runner) do
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
    timeout_ms = node.timeout_ms || 600_000
    {executable, args} = command_argv(node, prompt)

    Log.debug("llm node execute",
      node_id: node.id,
      model: node.model,
      prompt_file: node.prompt_file,
      timeout_ms: timeout_ms
    )

    case StreamCmd.run(executable, args, cd: ctx.workspace_root, timeout_ms: timeout_ms) do
      {:ok, {:timed_out, output, duration_ms}} ->
        {:ok, %RawResult{timed_out: true, stdout: output, duration_ms: duration_ms}}

      {:ok, {output, 0, duration_ms}} ->
        parse_json_output(output, duration_ms)

      {:ok, {output, code, duration_ms}} ->
        {:ok, %RawResult{exit_code: code, stdout: output, duration_ms: duration_ms, timed_out: false}}
    end
  end

  defp parse_json_output(output, duration_ms) do
    case extract_llm_json(output) do
      {:ok, map} ->
        {:ok,
         %RawResult{
           exit_code: 0,
           stdout: output,
           duration_ms: duration_ms,
           llm_json: map,
           signals: Map.get(map, "signals", %{})
         }}

      :error ->
        {:ok,
         %RawResult{
           exit_code: 0,
           stdout: output,
           duration_ms: duration_ms,
           llm_json: %{"status" => "ok", "raw" => output}
         }}
    end
  end

  defp extract_llm_json(output) do
    case Jason.decode(output) do
      {:ok, %{} = map} -> {:ok, map}
      _ -> extract_llm_json_from_lines(output)
    end
  end

  defp extract_llm_json_from_lines(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(&decode_llm_line/1)
    |> case do
      {:ok, _} = ok -> ok
      _ -> :error
    end
  end

  defp decode_llm_line(line) do
    case Jason.decode(line) do
      {:ok, %{"status" => _} = map} -> {:ok, map}
      {:ok, %{"type" => "result", "result" => %{} = result}} -> {:ok, result}
      _ -> nil
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

  defp command_argv(%NodeDefinition{command: cmd}, prompt) when is_list(cmd) and cmd != [] do
    case Enum.split(cmd, -1) do
      {prefix, ["--"]} -> split_executable(prefix ++ ["--", prompt])
      _ -> split_executable(cmd ++ [prompt])
    end
  end

  defp command_argv(_node, _prompt), do: split_executable(llm_command())

  defp split_executable([executable | args]), do: {executable, args}
  defp split_executable(_), do: {"", []}

  defp llm_command do
    case System.get_env("DEFINITIVELY_LLM_COMMAND") do
      nil ->
        [
          "sh",
          "-c",
          "printf '%s' '{\"status\":\"ok\",\"signals\":{\"fix_complete\":true}}'"
        ]

      line ->
        String.split(line, " ", trim: true)
    end
  end
end
