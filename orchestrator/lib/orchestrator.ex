defmodule Orchestrator do
  @moduledoc """
  FSM-based CLI/LLM workflow orchestrator.

  Core modules:

    * `Orchestrator.Outcome` — rich node results (beyond exit codes)
    * `Orchestrator.Workflow.Engine` — `:gen_statem` workflow runner
  """

  alias Orchestrator.Workflow.Engine

  @doc """
  Runs the default lint → fix → commit state machine until `:done`.
  """
  @spec run_demo() :: :ok | {:error, term()}
  def run_demo do
    {:ok, pid} = :gen_statem.start(Engine, [], [])

    :ok = :gen_statem.call(pid, {:start, :default})
    :ok = :gen_statem.call(pid, {:node_result, Orchestrator.Outcome.failure()})
    :ok = :gen_statem.call(pid, {:node_result, Orchestrator.Outcome.success()})
    :ok = :gen_statem.call(pid, {:node_result, Orchestrator.Outcome.success()})
    :ok = :gen_statem.call(pid, {:node_result, Orchestrator.Outcome.success()})
    :finished = :gen_statem.call(pid, :noop)

    :ok = :gen_statem.stop(pid)
    :ok
  end
end
