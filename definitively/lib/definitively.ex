defmodule Definitively do
  @moduledoc """
  FSM-based CLI/LLM workflow definitively.

  Core modules:

    * `Definitively.Outcome` — rich node results (beyond exit codes)
    * `Definitively.Workflow.Engine` — data-driven `:gen_statem` workflow runner
    * `Definitively.Spec.Loader` — YAML program loader
  """

  alias Definitively.Outcome
  alias Definitively.Workflow.Engine

  @doc """
  Runs the `dev_quality_loop` fixture program: lint → fix → commit → done.
  """
  @spec run_demo() :: :ok | {:error, term()}
  def run_demo do
    {:ok, pid} = Engine.start_link([])

    :ok = :gen_statem.call(pid, {:start, :default})
    :ok = :gen_statem.call(pid, {:node_result, Outcome.failure()})
    :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    :ok = :gen_statem.call(pid, {:node_result, Outcome.success()})
    :finished = :gen_statem.call(pid, :noop)

    :ok = :gen_statem.stop(pid)
    :ok
  end
end
