defmodule Definitively.Maestro.RunState do
  @moduledoc """
  Read/write maestro run context under `.definitively/state/`.

  `maestro-run.json` is the working copy (may be read by LLM prompts).
  `maestro-sealed.json` holds definitively-owned keys that LLM steps must not clobber.
  """

  @filename "maestro-run.json"
  @sealed_filename "maestro-sealed.json"

  @sealed_keys ~w(plan_file spec_path decompose_file mission_id task_id task_slug)

  @type t :: map()

  @doc "Returns the state file path under the workspace `.definitively/state/` directory."
  @spec path(Path.t()) :: Path.t()
  def path(workspace_root), do: Path.join([workspace_root, ".definitively", "state", @filename])

  @doc "Returns the sealed state file path."
  @spec sealed_path(Path.t()) :: Path.t()
  def sealed_path(workspace_root), do: Path.join([workspace_root, ".definitively", "state", @sealed_filename])

  @doc "Loads run state; missing file returns empty map."
  @spec load(Path.t()) :: t()
  def load(workspace_root), do: read_json(path(workspace_root))

  @doc "Loads sealed state; missing file returns empty map."
  @spec load_sealed(Path.t()) :: t()
  def load_sealed(workspace_root), do: read_json(sealed_path(workspace_root))

  @doc "Returns a value from sealed state first, then working state."
  @spec get(Path.t(), String.t()) :: term()
  def get(workspace_root, key) when is_binary(key) do
    load_sealed(workspace_root)[key] || load(workspace_root)[key]
  end

  @doc "Merges keys into run state and persists."
  @spec put(Path.t(), t()) :: :ok | {:error, term()}
  def put(workspace_root, attrs) when is_map(attrs) do
    attrs = stringify_keys(attrs)
    state = load(workspace_root) |> Map.merge(sanitize_put(attrs))
    write(path(workspace_root), state)
  end

  @doc "Persists protected keys to sealed state (definitively maestro nodes only)."
  @spec seal(Path.t(), t()) :: :ok | {:error, term()}
  def seal(workspace_root, attrs) when is_map(attrs) do
    sealed =
      attrs
      |> stringify_keys()
      |> Map.take(@sealed_keys)
      |> drop_empty()

    if sealed == %{} do
      :ok
    else
      state = load_sealed(workspace_root) |> Map.merge(sealed)
      write(sealed_path(workspace_root), state)
    end
  end

  @doc "Initializes plan file from options or `DEFINITIVELY_PLAN_FILE` env."
  @spec init_plan(Path.t(), map() | nil) :: :ok | {:error, term()}
  def init_plan(workspace_root, opts \\ nil) do
    plan_file =
      plan_from_opts(opts) ||
        System.get_env("DEFINITIVELY_PLAN_FILE") ||
        System.get_env("DEFINITIVELY_PLAN")

    if is_binary(plan_file) and plan_file != "" do
      expanded = Path.expand(plan_file, workspace_root)
      put(workspace_root, %{"plan_file" => expanded})
      seal(workspace_root, %{"plan_file" => expanded})
    else
      {:error, {:missing_plan_file, "set DEFINITIVELY_PLAN_FILE or options.plan_file"}}
    end
  end

  defp plan_from_opts(%{"plan_file" => path}) when is_binary(path), do: path
  defp plan_from_opts(%{plan_file: path}) when is_binary(path), do: path
  defp plan_from_opts(_), do: nil

  defp sanitize_put(attrs) do
    Map.new(attrs, fn {k, v} ->
      if k in @sealed_keys and empty_value?(v), do: {k, :__drop__}, else: {k, v}
    end)
    |> Enum.reject(fn {_k, v} -> v == :__drop__ end)
    |> Map.new()
  end

  defp drop_empty(map) do
    Map.drop(map, Enum.filter(map, fn {_k, v} -> empty_value?(v) end) |> Enum.map(&elem(&1, 0)))
  end

  defp empty_value?(nil), do: true
  defp empty_value?(v) when v in ["", :__drop__], do: true
  defp empty_value?(_), do: false

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp read_json(path) do
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

  defp write(path, state) do
    File.mkdir_p!(Path.dirname(path))

    case Jason.encode(state) do
      {:ok, json} -> File.write(path, json <> "\n")
      {:error, reason} -> {:error, reason}
    end
  end
end
