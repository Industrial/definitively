defmodule Definitively.Log.RunFile do
  @moduledoc """
  Mirrors definitively Logger output to a single log file for the duration of
  a workflow run: `.definitively/logs/<timestamp>-<program>.log`.
  """

  alias Definitively.Log
  alias Definitively.Workspace

  @handler_id :definitively_run_log
  @active_key :definitively_run_log_active

  @doc false
  @spec with_log(Path.t(), Path.t(), keyword(), (keyword() -> term())) :: term()
  def with_log(workspace_root, program_path, opts, fun)
      when is_list(opts) and is_function(fun, 1) do
    cond do
      not enabled?() -> fun.(opts)
      Process.get(@active_key) -> fun.(opts)
      true -> open_and_run_log(workspace_root, program_path, opts, fun)
    end
  end

  defp open_and_run_log(workspace_root, program_path, opts, fun) do
    run_id = Keyword.get(opts, :run_id) || generate_run_id()
    opts = Keyword.put(opts, :run_id, run_id)
    path = log_path(workspace_root, program_path)

    case open!(path) do
      :ok ->
        Process.put(@active_key, path)
        Application.put_env(:definitively, :run_log_path, path)
        Log.info("run log opened", log_file: path, run_id: run_id)

        try do
          fun.(opts)
        after
          close!()
          Process.delete(@active_key)
        end

      {:error, reason} ->
        Log.warn("run log unavailable", error: inspect(reason))
        fun.(opts)
    end
  end

  @doc false
  @spec with_log_for_program(Path.t(), keyword(), (keyword() -> term())) :: term()
  def with_log_for_program(program_path, opts, fun) when is_function(fun, 1) do
    with_log(workspace_for(program_path, opts), program_path, opts, fun)
  end

  @doc false
  @spec clear_run_log_path!() :: :ok
  def clear_run_log_path! do
    Application.delete_env(:definitively, :run_log_path)
    :ok
  end

  @doc false
  @spec log_path(Path.t(), Path.t()) :: Path.t()
  def log_path(workspace_root, program_path) do
    dir = Path.join([workspace_root, ".definitively", "logs"])
    slug = program_slug(program_path)
    Path.join(dir, "#{timestamp()}-#{slug}.log")
  end

  @doc false
  @spec generate_run_id() :: String.t()
  def generate_run_id do
    "run-" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  defp enabled? do
    case System.get_env("DEFINITIVELY_RUN_LOG") do
      nil ->
        true

      value ->
        value
        |> String.trim()
        |> String.downcase()
        |> case do
          "0" -> false
          "false" -> false
          "no" -> false
          "off" -> false
          _ -> true
        end
    end
  end

  defp open!(path) do
    File.mkdir_p!(Path.dirname(path))

    formatter = {:logger_formatter, %{single_line: true}}

    config = %{
      file: String.to_charlist(path),
      modes: [:write],
      max_no_files: 1,
      max_no_bytes: 50_000_000
    }

    case :logger.add_handler(@handler_id, :logger_std_h, %{
           config: config,
           formatter: formatter,
           level: :all
         }) do
      :ok ->
        :ok

      {:error, {:already_exists, _}} ->
        :logger.remove_handler(@handler_id)
        open!(path)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp close! do
    case :logger.remove_handler(@handler_id) do
      :ok -> :ok
      {:error, {:not_found, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp workspace_for(program_path, opts) do
    case Keyword.get(opts, :workspace_root) do
      root when is_binary(root) ->
        root

      _ ->
        case Workspace.resolve_run(program_path) do
          {:ok, %{workspace_root: root}} -> root
          _ -> System.get_env("DEFINITIVELY_WORKSPACE") || File.cwd!()
        end
    end
  end

  defp program_slug(program_path) do
    program_path
    |> Path.basename()
    |> Path.rootname()
    |> sanitize()
  end

  defp sanitize(name) when is_binary(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9._-]+/, "-")
    |> String.trim("-")
  end

  defp timestamp do
    %DateTime{microsecond: {us, _}} = dt = DateTime.utc_now()
    base = Calendar.strftime(dt, "%Y%m%d-%H%M%S")
    base <> "." <> String.pad_leading(Integer.to_string(us), 6, "0")
  end
end
