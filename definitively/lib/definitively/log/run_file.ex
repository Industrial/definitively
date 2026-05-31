defmodule Definitively.Log.RunFile do
  @moduledoc """
  Mirrors definitively Logger output to `.definitively/logs/<timestamp>-<program>.log`
  for the duration of a workflow run.
  """

  alias Definitively.Log
  alias Definitively.Spec.Loader
  alias Definitively.Workspace

  @handler_id :definitively_run_log

  @doc false
  @spec with_log(Path.t(), Path.t(), (-> term())) :: term()
  def with_log(workspace_root, program_path, fun) when is_function(fun, 0) do
    if enabled?() do
      path = log_path(workspace_root, program_path)

      case open!(path) do
        :ok ->
          Application.put_env(:definitively, :run_log_path, path)
          Log.info("run log opened", log_file: path)

          try do
            fun.()
          after
            close!()
          end

        {:error, reason} ->
          Log.warn("run log unavailable", error: inspect(reason))
          fun.()
      end
    else
      fun.()
    end
  end

  @doc false
  @spec with_log_for_program(Path.t(), keyword(), (-> term())) :: term()
  def with_log_for_program(program_path, opts, fun) when is_function(fun, 0) do
    with_log(workspace_for(program_path, opts), program_path, fun)
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
    timestamp = timestamp()
    slug = program_slug(program_path)
    Path.join(dir, "#{timestamp}-#{slug}.log")
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
      modes: [:write, :append],
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
    case Loader.load(program_path) do
      {:ok, program} -> sanitize(program.id)
      _ -> sanitize(Path.basename(program_path, Path.extname(program_path)))
    end
  end

  defp sanitize(name) when is_binary(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9._-]+/, "-")
    |> String.trim("-")
  end

  defp timestamp do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%d-%H%M%S")
  end
end
