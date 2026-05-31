defmodule Definitively.Log do
  @moduledoc """
  Structured logging for the definitively.

  Level is controlled by `DEFINITIVELY_LOG_LEVEL` (default `INFO`):
  `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`.

  Built on OTP `Logger`; TRACE is emitted at debug priority with `[trace]` metadata.
  """

  require Logger

  @levels ~w(trace debug info warn error)a
  @level_order Map.new(Enum.with_index(@levels))

  @doc "Configures Logger and application log threshold from `DEFINITIVELY_LOG_LEVEL`."
  @spec configure!() :: :ok
  def configure! do
    level = configured_level()
    Application.put_env(:definitively, :log_level, level)
    Logger.configure(level: to_logger_level(level))
    :ok
  end

  @doc false
  @spec configured_level() :: level()
  def configured_level do
    System.get_env("DEFINITIVELY_LOG_LEVEL", "INFO")
    |> String.trim()
    |> String.downcase()
    |> case do
      "trace" ->
        :trace

      "debug" ->
        :debug

      "info" ->
        :info

      "warn" ->
        :warn

      "warning" ->
        :warn

      "error" ->
        :error

      other ->
        Logger.warning("invalid DEFINITIVELY_LOG_LEVEL=#{inspect(other)}, using info")

        :info
    end
  end

  @type level :: :trace | :debug | :info | :warn | :error

  @doc false
  @spec enabled?(level()) :: boolean()
  def enabled?(level) when level in @levels do
    Map.fetch!(@level_order, level) >= Map.fetch!(@level_order, configured_level())
  end

  @doc false
  @spec log(level(), String.t(), keyword()) :: :ok
  def log(level, message, metadata \\ []) when level in @levels do
    if enabled?(level) do
      Logger.log(to_logger_level(level), message, enrich_metadata(level, metadata))
    end

    :ok
  end

  @doc "Logs at trace level when enabled."
  @spec trace(String.t(), keyword()) :: :ok
  def trace(message, metadata \\ []), do: log(:trace, message, metadata)
  @doc "Logs at debug level when enabled."
  @spec debug(String.t(), keyword()) :: :ok
  def debug(message, metadata \\ []), do: log(:debug, message, metadata)
  @doc "Logs at info level when enabled."
  @spec info(String.t(), keyword()) :: :ok
  def info(message, metadata \\ []), do: log(:info, message, metadata)
  @doc "Logs at warn level when enabled."
  @spec warn(String.t(), keyword()) :: :ok
  def warn(message, metadata \\ []), do: log(:warn, message, metadata)
  @doc "Logs at error level when enabled."
  @spec error(String.t(), keyword()) :: :ok
  def error(message, metadata \\ []), do: log(:error, message, metadata)

  @doc "Builds metadata keyword list, dropping nil values."
  @spec metadata(keyword()) :: keyword()
  def metadata(opts), do: Enum.reject(opts, fn {_k, v} -> is_nil(v) end)

  @doc "Metadata from a run context."
  @spec run_metadata(Definitively.Workflow.RunContext.t()) :: keyword()
  def run_metadata(%Definitively.Workflow.RunContext{} = ctx) do
    metadata(run_id: ctx.run_id, workspace: ctx.workspace_root)
  end

  defp enrich_metadata(:trace, metadata),
    do: Keyword.put(metadata, :definitively_level, :trace)

  defp enrich_metadata(_level, metadata), do: metadata(metadata)

  defp to_logger_level(:trace), do: :debug
  defp to_logger_level(:debug), do: :debug
  defp to_logger_level(:info), do: :info
  defp to_logger_level(:warn), do: :warning
  defp to_logger_level(:error), do: :error
end
