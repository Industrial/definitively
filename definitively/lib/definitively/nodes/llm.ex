defmodule Definitively.Nodes.Llm do
  @moduledoc """
  Runs LLM nodes by invoking a configurable runner and parsing a JSON envelope.

  Configure `config :definitively, :llm_runner` as `{Mod, :fun, extra_args}` for
  tests; default runs a shell command from the node's `agent` profile, `command`
  list, or `DEFINITIVELY_LLM_COMMAND` stub.
  """

  @behaviour Definitively.Nodes.Executor

  alias Definitively.AgentProfile.{Builder, Loader, OutputParser}
  alias Definitively.Domain.{AgentProfile, NodeDefinition, RawResult}
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

    with {:ok, build} <- resolve_build(node, ctx, prompt) do
      execute_build(build, node, ctx, timeout_ms, prompt)
    end
  end

  defp resolve_build(node, ctx, prompt) do
    cond do
      is_list(node.command) and node.command != [] ->
        {:ok, {:command, command_argv(node, prompt), AgentProfile.legacy_output()}}

      agent_id = resolve_agent_id(node, ctx) ->
        with {:ok, profile} <- Loader.load(agent_id, ctx.workspace_root),
             {:ok, built} <- Builder.build(profile, node, prompt) do
          {:ok, {:profile, built, profile.output}}
        end

      true ->
        {:ok, {:command, command_argv(node, prompt), AgentProfile.legacy_output()}}
    end
  end

  defp resolve_agent_id(%NodeDefinition{agent: agent}, %RunContext{inputs: inputs}) do
    cond do
      not is_nil(agent) -> agent
      agent_input = Map.get(inputs, "agent") || Map.get(inputs, :agent) -> to_string(agent_input)
      env = System.get_env("DEFINITIVELY_AGENT") -> String.to_atom(env)
      true -> nil
    end
  end

  defp execute_build(
         {:command, {executable, args}, output_config},
         node,
         ctx,
         timeout_ms,
         _prompt
       ) do
    stream_run(executable, args, nil, node, ctx, timeout_ms, output_config)
  end

  defp execute_build(
         {:profile, {executable, args, stdin_prompt}, output_config},
         node,
         ctx,
         timeout_ms,
         _prompt
       ) do
    stream_run(executable, args, stdin_prompt, node, ctx, timeout_ms, output_config)
  end

  defp execute_build(
         {:profile, {executable, args}, output_config},
         node,
         ctx,
         timeout_ms,
         _prompt
       ) do
    stream_run(executable, args, nil, node, ctx, timeout_ms, output_config)
  end

  defp stream_run(executable, args, stdin_prompt, node, ctx, timeout_ms, output_config) do
    Log.debug("llm node execute",
      node_id: node.id,
      model: node.model,
      agent: node.agent,
      prompt_file: node.prompt_file,
      timeout_ms: timeout_ms
    )

    if is_binary(stdin_prompt) do
      run_with_stdin(executable, args, stdin_prompt, node, ctx, timeout_ms, output_config)
    else
      run_streaming(executable, args, node, ctx, timeout_ms, output_config)
    end
  end

  defp run_streaming(executable, args, _node, ctx, timeout_ms, output_config) do
    opts = [
      cd: ctx.workspace_root,
      timeout_ms: timeout_ms,
      complete: &OutputParser.stream_complete?(&1, output_config)
    ]

    case StreamCmd.run(executable, args, opts) do
      {:ok, {:timed_out, output, duration_ms}} ->
        {:ok, %RawResult{timed_out: true, stdout: output, duration_ms: duration_ms}}

      {:ok, {output, 0, duration_ms}} ->
        parse_output(output, duration_ms, output_config)

      {:ok, {output, code, duration_ms}} ->
        {:ok,
         %RawResult{exit_code: code, stdout: output, duration_ms: duration_ms, timed_out: false}}
    end
  end

  defp run_with_stdin(executable, args, prompt, _node, ctx, timeout_ms, output_config) do
    started = System.monotonic_time(:millisecond)
    exe = StreamCmd.resolve_executable(executable)

    port_opts = [
      :binary,
      :exit_status,
      {:args, Enum.map(args, &String.to_charlist/1)},
      {:cd, String.to_charlist(ctx.workspace_root)},
      :stderr_to_stdout
    ]

    port = Port.open({:spawn_executable, String.to_charlist(exe)}, port_opts)
    Port.command(port, prompt)

    case collect_stdin_port(port, timeout_ms, "", started) do
      {output, 0} ->
        duration_ms = System.monotonic_time(:millisecond) - started
        parse_output(output, duration_ms, output_config)

      {output, code} ->
        duration_ms = System.monotonic_time(:millisecond) - started

        {:ok,
         %RawResult{exit_code: code, stdout: output, duration_ms: duration_ms, timed_out: false}}

      {:timed_out, output, duration_ms} ->
        {:ok, %RawResult{timed_out: true, stdout: output, duration_ms: duration_ms}}
    end
  end

  defp collect_stdin_port(port, timeout_ms, acc, started) do
    receive do
      {^port, {:data, chunk}} ->
        collect_stdin_port(port, timeout_ms, acc <> chunk, started)

      {^port, {:exit_status, status}} ->
        {acc, status}
    after
      timeout_ms ->
        Port.close(port)
        duration_ms = System.monotonic_time(:millisecond) - started
        {:timed_out, acc, duration_ms}
    end
  end

  defp parse_output(output, duration_ms, output_config) do
    case OutputParser.parse(output, output_config) do
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

  @doc false
  @spec stream_complete?(String.t()) :: boolean()
  def stream_complete?(output) when is_binary(output) do
    OutputParser.stream_complete?(output, AgentProfile.legacy_output())
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
        ["printf", ~s({"status":"ok","signals":{"fix_complete":true}})]

      line ->
        String.split(line, " ", trim: true)
    end
  end
end
