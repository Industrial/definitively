defmodule Definitively.Domain.GhAction do
  @moduledoc "Pure gh argv builders and result parsers for GitHub CLI nodes."

  alias Definitively.Domain.NodeDefinition

  @type argv :: [String.t()]

  @doc "Builds gh argv for the given action and options."
  @spec build_argv(atom(), map() | nil) ::
          {:ok, argv() | {:multi, [argv()]} | {:resolve_then_watch, argv()}} | {:error, term()}
  def build_argv(:pr_create, opts) do
    title = Map.get(opts, "title") || Map.get(opts, :title)

    if is_binary(title) and title != "" do
      args =
        ["pr", "create", "--title", title]
        |> maybe_opt("--body", Map.get(opts, "body") || Map.get(opts, :body))
        |> maybe_opt("--base", Map.get(opts, "base") || Map.get(opts, :base))
        |> maybe_opt("--head", Map.get(opts, "head") || Map.get(opts, :head))
        |> maybe_add("--draft", truthy?(Map.get(opts, "draft") || Map.get(opts, :draft)))

      {:ok, args}
    else
      {:error, {:invalid_options, :pr_create, "title is required"}}
    end
  end

  def build_argv(:pr_view, opts) do
    cond do
      number = Map.get(opts, "number") || Map.get(opts, :number) ->
        {:ok, ["pr", "view", to_string(number), "--json", pr_view_fields()]}

      branch = Map.get(opts, "branch") || Map.get(opts, :branch) ->
        {:ok, ["pr", "view", to_string(branch), "--json", pr_view_fields()]}

      true ->
        {:error, {:invalid_options, :pr_view, "number or branch is required"}}
    end
  end

  def build_argv(:run_list, opts) do
    limit = to_string(Map.get(opts, "limit") || Map.get(opts, :limit) || 5)

    args =
      ["run", "list", "--limit", limit, "--json", run_list_fields()]
      |> maybe_opt("--workflow", Map.get(opts, "workflow") || Map.get(opts, :workflow))
      |> maybe_opt("--branch", Map.get(opts, "branch") || Map.get(opts, :branch))

    {:ok, args}
  end

  def build_argv(:run_watch, opts) do
    cond do
      run_id = Map.get(opts, "run_id") || Map.get(opts, :run_id) ->
        {:ok, ["run", "watch", to_string(run_id), "--exit-status"]}

      workflow = Map.get(opts, "workflow") || Map.get(opts, :workflow) ->
        list_args =
          [
            "run",
            "list",
            "--workflow",
            to_string(workflow),
            "--limit",
            "1",
            "--json",
            "databaseId"
          ]
          |> maybe_opt("--branch", Map.get(opts, "branch") || Map.get(opts, :branch))

        {:ok, {:resolve_then_watch, list_args}}

      true ->
        {:error, {:invalid_options, :run_watch, "run_id or workflow is required"}}
    end
  end

  def build_argv(:run_view, opts) do
    run_id = Map.get(opts, "run_id") || Map.get(opts, :run_id)

    if run_id do
      log_failed = truthy?(Map.get(opts, "log_failed") || Map.get(opts, :log_failed))
      view_args = ["run", "view", to_string(run_id), "--json", run_view_fields()]

      if log_failed do
        {:ok, {:multi, [view_args, ["run", "view", to_string(run_id), "--log-failed"]]}}
      else
        {:ok, view_args}
      end
    else
      {:error, {:invalid_options, :run_view, "run_id is required"}}
    end
  end

  def build_argv(action, _opts), do: {:error, {:unknown_action, action}}

  @doc "Builds argv for a gh node."
  @spec argv_for(NodeDefinition.t()) ::
          {:ok, argv() | {:multi, [argv()]} | {:resolve_then_watch, argv()}} | {:error, term()}
  def argv_for(%NodeDefinition{kind: :gh, action: action, options: opts}) do
    build_argv(action, opts || %{})
  end

  @doc "Parses gh JSON stdout into signals and data."
  @spec parse_result(atom(), non_neg_integer(), String.t()) :: {map(), map() | nil}
  def parse_result(:pr_create, 0, stdout) do
    url = String.trim(stdout)
    number = extract_pr_number(url)
    {%{}, %{"url" => url, "number" => number}}
  end

  def parse_result(:pr_view, 0, stdout) do
    case Jason.decode(stdout) do
      {:ok, data} when is_map(data) ->
        state = Map.get(data, "state")

        signals =
          %{}
          |> put_signal(:open, state == "OPEN")
          |> put_signal(:merged, state == "MERGED")
          |> put_signal(:closed, state == "CLOSED")

        {signals, data}

      _ ->
        {%{}, nil}
    end
  end

  def parse_result(:run_list, 0, stdout) do
    case Jason.decode(stdout) do
      {:ok, data} -> {%{}, %{"runs" => data}}
      _ -> {%{}, nil}
    end
  end

  def parse_result(:run_view, 0, stdout) do
    case Jason.decode(stdout) do
      {:ok, data} when is_map(data) ->
        conclusion = Map.get(data, "conclusion")
        signals = put_signal(%{}, :success, conclusion == "success")
        {signals, data}

      _ ->
        {%{}, nil}
    end
  end

  def parse_result(_action, _code, _stdout), do: {%{}, nil}

  @doc "Extracts run id from gh run list JSON output."
  @spec extract_run_id(String.t()) :: {:ok, String.t()} | {:error, :no_run_found}
  def extract_run_id(stdout) do
    case Jason.decode(stdout) do
      {:ok, [%{"databaseId" => id} | _]} -> {:ok, to_string(id)}
      {:ok, [id | _]} when is_integer(id) -> {:ok, to_string(id)}
      _ -> {:error, :no_run_found}
    end
  end

  defp pr_view_fields, do: "number,state,title,url,headRefName,baseRefName"
  defp run_list_fields, do: "databaseId,status,conclusion,workflowName,headBranch,url"
  defp run_view_fields, do: "databaseId,status,conclusion,workflowName,url,headBranch"

  defp extract_pr_number(url) do
    case Regex.run(~r/pull\/(\d+)/, url) do
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  end

  defp maybe_opt(args, _flag, nil), do: args
  defp maybe_opt(args, flag, value), do: args ++ [flag, to_string(value)]

  defp maybe_add(args, flag, true), do: args ++ [flag]
  defp maybe_add(args, _flag, false), do: args

  defp put_signal(signals, key, true), do: Map.put(signals, key, true)
  defp put_signal(signals, _key, false), do: signals

  defp truthy?(value) when value in [true, "true", 1, "1"], do: true
  defp truthy?(_), do: false
end
