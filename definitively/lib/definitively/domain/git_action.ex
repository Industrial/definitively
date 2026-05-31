defmodule Definitively.Domain.GitAction do
  @moduledoc "Pure git argv builders and result parsers for git nodes."

  alias Definitively.Domain.NodeDefinition

  @type argv :: [String.t()]

  @doc "Builds git argv for the given action and options."
  @spec build_argv(atom(), map() | nil) :: {:ok, argv() | {:multi, [argv()]}} | {:error, term()}
  def build_argv(:status, _opts), do: {:ok, ["status", "--porcelain=v1", "-b"]}

  def build_argv(:diff, opts) do
    args =
      []
      |> maybe_add("--staged", truthy?(Map.get(opts, "staged") || Map.get(opts, :staged)))
      |> maybe_add("--stat", truthy?(Map.get(opts, "stat") || Map.get(opts, :stat)))
      |> then(&["diff" | &1])

    {:ok, args}
  end

  def build_argv(:add, opts), do: build_add_argv(opts)
  def build_argv(:commit, opts), do: build_commit_argv(opts)
  def build_argv(:push, opts), do: build_push_argv(opts)
  def build_argv(:tag, opts), do: build_tag_argv(opts)
  def build_argv(action, _opts), do: {:error, {:unknown_action, action}}

  @doc "Builds argv list(s) for a git node."
  @spec argv_for(NodeDefinition.t()) :: {:ok, argv() | {:multi, [argv()]}} | {:error, term()}
  def argv_for(%NodeDefinition{kind: :git, action: action, options: opts}) do
    build_argv(action, opts || %{})
  end

  @doc "Parses stdout into signals and structured data for a git action."
  @spec parse_result(atom(), non_neg_integer(), String.t()) :: {map(), map()}
  def parse_result(:status, 0, stdout) do
    {branch_line, porcelain} = split_status_output(stdout)
    dirty = String.trim(porcelain) != ""

    signals =
      %{}
      |> put_signal(:clean, not dirty)
      |> put_signal(:dirty, dirty)
      |> put_branch_signals(branch_line)

    data = %{
      "clean" => not dirty,
      "dirty" => dirty,
      "branch" => branch_line
    }

    {signals, data}
  end

  def parse_result(:diff, 0, stdout) do
    has_changes = String.trim(stdout) != ""
    {put_signal(%{}, :has_changes, has_changes), %{"has_changes" => has_changes}}
  end

  def parse_result(:diff, _code, _stdout), do: {%{}, %{}}
  def parse_result(_action, _code, _stdout), do: {%{}, %{}}

  defp build_add_argv(opts) do
    cond do
      truthy?(Map.get(opts, "all") || Map.get(opts, :all)) ->
        {:ok, ["add", "-A"]}

      paths = Map.get(opts, "paths") || Map.get(opts, :paths) ->
        if is_list(paths) and paths != [] do
          {:ok, ["add" | Enum.map(paths, &to_string/1)]}
        else
          {:error, {:invalid_options, :add, "paths must be a non-empty list"}}
        end

      true ->
        {:error, {:invalid_options, :add, "requires all: true or paths: [...]"}}
    end
  end

  defp build_commit_argv(opts) do
    message = Map.get(opts, "message") || Map.get(opts, :message)

    if is_binary(message) and message != "" do
      args =
        ["commit", "-m", message]
        |> maybe_add("--amend", truthy?(Map.get(opts, "amend") || Map.get(opts, :amend)))
        |> maybe_add(
          "--allow-empty",
          truthy?(Map.get(opts, "allow_empty") || Map.get(opts, :allow_empty))
        )

      case stage_argv_for_commit(opts) do
        {:ok, add_argv} -> {:ok, {:multi, [add_argv, args]}}
        :skip -> {:ok, args}
      end
    else
      {:error, {:invalid_options, :commit, "message is required"}}
    end
  end

  defp stage_argv_for_commit(opts) do
    cond do
      Map.get(opts, "add") == "all" || Map.get(opts, :add) == "all" ->
        {:ok, ["add", "-A"]}

      paths = Map.get(opts, "add") || Map.get(opts, :add) ->
        if is_list(paths), do: {:ok, ["add" | Enum.map(paths, &to_string/1)]}, else: :skip

      true ->
        :skip
    end
  end

  defp build_push_argv(opts) do
    remote = to_string(Map.get(opts, "remote") || Map.get(opts, :remote) || "origin")
    branch = Map.get(opts, "branch") || Map.get(opts, :branch)
    set_upstream = truthy?(Map.get(opts, "set_upstream") || Map.get(opts, :set_upstream))
    push_tags = truthy?(Map.get(opts, "tags") || Map.get(opts, :tags))

    args =
      ["push"]
      |> maybe_add("--set-upstream", set_upstream)
      |> Kernel.++([remote])
      |> then(fn a -> if branch, do: a ++ [to_string(branch)], else: a end)

    args = if push_tags, do: args ++ ["--tags"], else: args
    {:ok, args}
  end

  defp build_tag_argv(opts) do
    name = Map.get(opts, "name") || Map.get(opts, :name)

    with true <- is_binary(name) and name != "",
         tag_args <-
           tag_create_argv(
             name,
             Map.get(opts, "message") || Map.get(opts, :message),
             truthy?(Map.get(opts, "annotate") || Map.get(opts, :annotate))
           ) do
      maybe_push_tag(tag_args, name, opts)
    else
      _ -> {:error, {:invalid_options, :tag, "name is required"}}
    end
  end

  defp maybe_push_tag(tag_args, name, opts) do
    if truthy?(Map.get(opts, "push") || Map.get(opts, :push)) do
      remote = to_string(Map.get(opts, "remote") || Map.get(opts, :remote) || "origin")
      {:ok, {:multi, [tag_args, ["push", remote, to_string(name)]]}}
    else
      {:ok, tag_args}
    end
  end

  defp tag_create_argv(name, message, annotate) do
    if annotate and is_binary(message) and message != "" do
      ["tag", "-a", to_string(name), "-m", message]
    else
      ["tag", to_string(name)]
    end
  end

  defp split_status_output(stdout) do
    lines = String.split(stdout, "\n", trim: true)

    case lines do
      [branch | rest] -> {branch, Enum.join(rest, "\n")}
      [] -> {"", ""}
    end
  end

  defp put_branch_signals(signals, "## " <> rest) do
    cond do
      String.contains?(rest, "[ahead ") -> put_signal(signals, :ahead, true)
      String.contains?(rest, "[behind ") -> put_signal(signals, :behind, true)
      true -> signals
    end
  end

  defp put_branch_signals(signals, _), do: signals

  defp put_signal(signals, key, true), do: Map.put(signals, key, true)
  defp put_signal(signals, _key, false), do: signals

  defp maybe_add(args, flag, true), do: args ++ [flag]
  defp maybe_add(args, _flag, false), do: args

  defp truthy?(value) when value in [true, "true", 1, "1"], do: true
  defp truthy?("all"), do: true
  defp truthy?(_), do: false
end
