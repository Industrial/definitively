defmodule Definitively.Maestro.RunState do
  @moduledoc "Read/write `.definitively/state/maestro-run.json` for cross-node maestro context."

  @filename "maestro-run.json"

  @type t :: map()

  @doc "Returns the state file path under the workspace `.definitively/state/` directory."
  @spec path(Path.t()) :: Path.t()
  def path(workspace_root) do
    Path.join([workspace_root, ".definitively", "state", @filename])
  end

  @doc "Loads run state; missing file returns empty map."
  @spec load(Path.t()) :: t()
  def load(workspace_root) do
    path = path(workspace_root)

    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, map} when is_map(map) -> map
          _ -> %{}
        end

      {:error, :enoent} ->
        %{}

      {:error, _} ->
        %{}
    end
  end

  @doc "Merges keys into run state and persists."
  @spec put(Path.t(), t()) :: :ok | {:error, term()}
  def put(workspace_root, attrs) when is_map(attrs) do
    state = load(workspace_root) |> Map.merge(stringify_keys(attrs))
    write(workspace_root, state)
  end

  @doc "Initializes plan file from options or `DEFINITIVELY_PLAN_FILE` env."
  @spec init_plan(Path.t(), map() | nil) :: :ok | {:error, term()}
  def init_plan(workspace_root, opts \\ nil) do
    plan_file =
      plan_from_opts(opts) ||
        System.get_env("DEFINITIVELY_PLAN_FILE") ||
        System.get_env("DEFINITIVELY_PLAN")

    if is_binary(plan_file) and plan_file != "" do
      put(workspace_root, %{"plan_file" => Path.expand(plan_file, workspace_root)})
    else
      {:error, {:missing_plan_file, "set DEFINITIVELY_PLAN_FILE or options.plan_file"}}
    end
  end

  defp plan_from_opts(%{"plan_file" => path}) when is_binary(path), do: path
  defp plan_from_opts(%{plan_file: path}) when is_binary(path), do: path
  defp plan_from_opts(_), do: nil

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp write(workspace_root, state) do
    path = path(workspace_root)
    File.mkdir_p!(Path.dirname(path))

    case Jason.encode(state) do
      {:ok, json} -> File.write(path, json <> "\n")
      {:error, reason} -> {:error, reason}
    end
  end
end
