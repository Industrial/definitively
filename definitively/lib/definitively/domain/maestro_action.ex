defmodule Definitively.Domain.MaestroAction do
  @moduledoc "Pure maestro argv builders and result parsers for maestro nodes."

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Maestro.RunState

  @type argv :: [String.t()]

  @doc "Builds maestro CLI argv for the given action and options."
  @spec build_argv(atom(), map() | nil, Path.t()) ::
          {:ok, argv() | {:multi, [argv()]}} | {:error, term()}
  def build_argv(:init_run, _opts, _workspace), do: {:ok, :init_run}

  def build_argv(:spec_validate, opts, workspace) do
    with {:ok, path} <- require_path(opts, workspace, "spec_path", "plan-derived spec") do
      {:ok, ["spec", "validate", path]}
    end
  end

  def build_argv(:mission_from_spec, opts, workspace) do
    with {:ok, path} <- require_path(opts, workspace, "spec_path", "product spec") do
      {:ok, ["mission", "from-spec", path]}
    end
  end

  def build_argv(:mission_decompose, opts, workspace) do
    with {:ok, mission_id} <- require_state_or_opt(opts, workspace, "mission_id"),
         {:ok, file} <- require_path(opts, workspace, "decompose_file", "decompose batch JSON") do
      {:ok, ["mission", "decompose", mission_id, "--file", file]}
    end
  end

  def build_argv(:task_claim_next, opts, workspace) do
    case require_state_or_opt(opts, workspace, "mission_id") do
      {:ok, mission_id} ->
        {:ok, {:claim_next, mission_id}}

      {:error, _} = err ->
        err
    end
  end

  def build_argv(:evidence_record, opts, workspace) do
    with {:ok, task_id} <- require_state_or_opt(opts, workspace, "task_id"),
         command <- Map.get(opts, "command") || Map.get(opts, :command) ||
           ".maestro/bootstrap/validation/verify-gate.sh",
         exit <- Map.get(opts, "exit") || Map.get(opts, :exit) || 0 do
      {:ok,
       [
         "evidence",
         "record",
         "--task",
         task_id,
         "--command",
         to_string(command),
         "--exit",
         to_string(exit)
       ]}
    end
  end

  def build_argv(:task_verify, opts, workspace) do
    with {:ok, task_id} <- require_state_or_opt(opts, workspace, "task_id") do
      {:ok, ["task", "verify", task_id]}
    end
  end

  def build_argv(:verdict_request, opts, workspace) do
    with {:ok, task_id} <- require_state_or_opt(opts, workspace, "task_id") do
      {:ok, ["verdict", "request", "--task", task_id]}
    end
  end

  def build_argv(:task_ship, opts, workspace) do
    with {:ok, task_id} <- require_state_or_opt(opts, workspace, "task_id") do
      {:ok, ["task", "ship", task_id]}
    end
  end

  def build_argv(action, _opts, _workspace), do: {:error, {:unknown_action, action}}

  @doc "Builds argv for a maestro node."
  @spec argv_for(NodeDefinition.t(), Path.t()) ::
          {:ok, argv() | {:multi, [argv()]} | {:claim_next, String.t()}} | {:error, term()}
  def argv_for(%NodeDefinition{kind: :maestro, action: action, options: opts}, workspace) do
    build_argv(action, opts || %{}, workspace)
  end

  @doc "Parses stdout into signals and structured data for a maestro action."
  @spec parse_result(atom(), non_neg_integer(), String.t(), Path.t()) :: {map(), map()}
  def parse_result(:init_run, 0, _stdout, workspace) do
    state = RunState.load(workspace)
    {%{}, state}
  end

  def parse_result(:mission_from_spec, 0, stdout, workspace) do
    case extract_id(stdout, ~r/(pln-[a-z0-9-]+)/) do
      {:ok, mission_id} ->
        spec_path = RunState.get(workspace, "spec_path")

        RunState.put(workspace, %{"mission_id" => mission_id, "spec_path" => spec_path})
        RunState.seal(workspace, %{"mission_id" => mission_id, "spec_path" => spec_path})

        {%{}, %{"mission_id" => mission_id}}

      :error ->
        {put_signal(%{}, :parse_failed, true),
         %{"error" => "mission_id not found in maestro mission from-spec stdout"}}
    end
  end

  def parse_result(:task_claim_next, 0, _stdout, workspace) do
    case RunState.get(workspace, "task_id") do
      id when is_binary(id) and id != "" ->
        {put_signal(%{}, :has_tasks, true),
         %{"has_tasks" => true, "task_id" => id, "task_slug" => RunState.get(workspace, "task_slug")}}

      _ ->
        {put_signal(%{}, :no_tasks, true), %{"has_tasks" => false}}
    end
  end

  def parse_result(_action, 0, stdout, _workspace) do
    data =
      case Jason.decode(stdout) do
        {:ok, map} when is_map(map) -> map
        _ -> %{"stdout" => String.trim(stdout)}
      end

    {%{}, data}
  end

  def parse_result(_action, _code, _stdout, _workspace), do: {%{}, %{}}

  @doc "Runs the composite claim-next flow: list draft tasks, claim first or mark empty."
  @spec run_claim_next(String.t(), Path.t(), (String.t(), [String.t()], keyword() -> term())) ::
          {:ok, {non_neg_integer(), String.t(), map(), map()}} | {:error, term()}
  def run_claim_next(mission_id, workspace, runner) when is_function(runner, 3) do
    list_argv = [
      "task",
      "list",
      "--mission-id",
      mission_id,
      "--state",
      "draft",
      "--json",
      "--all"
    ]

    case runner.("maestro", list_argv, cd: workspace, timeout_ms: 120_000) do
      {:ok, %{exit_code: 0, stdout: stdout}} ->
        handle_claim_list(mission_id, workspace, stdout, runner)

      {:ok, raw} ->
        {:ok, {raw.exit_code || 1, raw.stdout || "", %{}, %{}}}

      {:error, _} = err ->
        err
    end
  end

  defp handle_claim_list(mission_id, workspace, stdout, runner) do
    case Jason.decode(stdout) do
      {:ok, %{"items" => items}} ->
        handle_claim_items(mission_id, workspace, items, stdout, runner)

      _ ->
        {:ok, {1, stdout, %{}, %{"error" => "failed to parse task list"}}}
    end
  end

  defp handle_claim_items(_mission_id, workspace, [], _stdout, _runner) do
    RunState.put(workspace, %{"task_id" => nil, "task_slug" => nil})

    signals = put_signal(%{}, :no_tasks, true)
    data = %{"has_tasks" => false}
    {:ok, {0, "", signals, data}}
  end

  defp handle_claim_items(mission_id, workspace, [%{"id" => task_id, "slug" => slug} | _], _stdout, runner) do
    run_task_claim(mission_id, workspace, task_id, slug, runner)
  end

  defp handle_claim_items(_mission_id, _workspace, _items, stdout, _runner) do
    {:ok, {1, stdout, %{}, %{"error" => "invalid task list JSON"}}}
  end

  defp run_task_claim(mission_id, workspace, task_id, slug, runner) do
    claim_argv = ["task", "claim", task_id]

    case runner.("maestro", claim_argv, cd: workspace, timeout_ms: 120_000) do
      {:ok, %{exit_code: 0} = raw} ->
        attrs = %{
          "mission_id" => mission_id,
          "task_id" => task_id,
          "task_slug" => slug
        }

        RunState.put(workspace, attrs)
        RunState.seal(workspace, attrs)

        signals = put_signal(%{}, :has_tasks, true)

        data = %{
          "has_tasks" => true,
          "task_id" => task_id,
          "task_slug" => slug
        }

        {:ok, {0, raw.stdout || "", signals, data}}

      {:ok, raw} ->
        {:ok, {raw.exit_code || 1, raw.stdout || "", %{}, %{}}}

      {:error, _} = err ->
        err
    end
  end

  defp require_path(opts, workspace, key, label) do
    path =
      Map.get(opts, key) || Map.get(opts, String.to_atom(key)) || RunState.get(workspace, key)

    cond do
      is_binary(path) and path != "" ->
        {:ok, Path.expand(path, workspace)}

      key == "spec_path" and is_binary(RunState.get(workspace, "plan_file")) ->
        slug = slug_from_plan(RunState.get(workspace, "plan_file"))
        {:ok, Path.expand(".maestro/specs/#{slug}.md", workspace)}

      true ->
        {:error, {:invalid_options, String.to_atom(key), "#{label} path is required"}}
    end
  end

  defp require_state_or_opt(opts, workspace, key) do
    value = Map.get(opts, key) || Map.get(opts, String.to_atom(key)) || RunState.get(workspace, key)

    if is_binary(value) and value != "" do
      {:ok, value}
    else
      {:error, {:invalid_options, String.to_atom(key), "#{key} is required in run state or options"}}
    end
  end

  defp slug_from_plan(plan_file) do
    plan_file
    |> Path.basename()
    |> String.replace_suffix(".plan.md", "")
    |> String.replace_suffix(".md", "")
    |> slugify()
  end

  defp slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp extract_id(stdout, regex) do
    case Regex.run(regex, stdout) do
      [_, id] -> {:ok, id}
      _ -> :error
    end
  end

  defp put_signal(signals, key, true), do: Map.put(signals, key, true)
end
