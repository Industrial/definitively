defmodule Definitively.Nodes.CmdExec do
  @moduledoc "Shared subprocess runner for structured git/gh node executors."

  alias Definitively.Domain.RawResult
  alias Definitively.Nodes.StreamCmd

  @doc "Runs a single executable with args in cwd."
  @spec run(String.t(), [String.t()], keyword()) ::
          {:ok, RawResult.t()} | {:ok, {:timed_out, RawResult.t()}}
  def run(executable, args, opts) do
    cwd = Keyword.fetch!(opts, :cd)
    timeout_ms = Keyword.get(opts, :timeout_ms, 120_000)

    case StreamCmd.run(executable, args, cd: cwd, timeout_ms: timeout_ms) do
      {:ok, {:timed_out, output, duration_ms}} ->
        {:ok,
         {:timed_out,
          %RawResult{
            timed_out: true,
            stdout: output,
            duration_ms: duration_ms
          }}}

      {:ok, {output, exit_code, duration_ms}} ->
        {:ok,
         %RawResult{
           exit_code: exit_code,
           stdout: output,
           stderr: "",
           duration_ms: duration_ms,
           timed_out: false
         }}
    end
  end

  @doc "Runs argv sequences sequentially; stops on first non-zero exit or timeout."
  @spec run_argv(String.t(), [String.t()] | {:multi, [[String.t()]]}, keyword()) ::
          {:ok, RawResult.t()} | {:error, term()}
  def run_argv(executable, argv_or_multi, opts)

  def run_argv(executable, args, opts) when is_list(args) and not is_struct(args) do
    case hd(args) do
      first when is_binary(first) ->
        run(executable, args, opts)

      _ ->
        run_multi(executable, args, opts)
    end
  end

  def run_argv(executable, {:multi, argvs}, opts) do
    run_multi(executable, argvs, opts)
  end

  defp run_multi(executable, argvs, opts) do
    Enum.reduce_while(argvs, {:ok, empty_result()}, fn args, _acc ->
      case run(executable, args, opts) do
        {:ok, {:timed_out, raw}} ->
          {:halt, {:ok, raw}}

        {:ok, %RawResult{exit_code: 0} = raw} ->
          {:cont, {:ok, raw}}

        {:ok, raw} ->
          {:halt, {:ok, raw}}
      end
    end)
  end

  defp empty_result, do: %RawResult{exit_code: 0, stdout: "", timed_out: false}
end
