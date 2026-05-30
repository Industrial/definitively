defmodule Orchestrator.Run.Coordinator do
  @moduledoc """
  Application facade for starting and controlling ephemeral workflow runs.
  """

  alias Orchestrator.Domain.Program
  alias Orchestrator.Nodes.ExecutorRouter
  alias Orchestrator.Outcome.Evaluator
  alias Orchestrator.Run.Snapshot
  alias Orchestrator.Spec.Loader
  alias Orchestrator.Workflow.{Engine, RunContext}

  @registry Orchestrator.Run.Registry
  @supervisor Orchestrator.Run.EngineSupervisor

  @doc "Starts a run from a YAML program path; drives active nodes until a final state."
  @spec run_until_final(Path.t(), keyword()) :: :ok | {:error, term()}
  def run_until_final(program_path, opts \\ []) do
    with {:ok, run_id} <- start(program_path, opts) do
      drive(run_id, opts)
    end
  end

  @doc "Loads a program and starts an engine process registered by `run_id`."
  @spec start(Path.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def start(program_path, opts \\ []) do
    with {:ok, program} <- Loader.load(program_path) do
      start_program(program, opts)
    end
  end

  @doc "Returns a snapshot of the run's current FSM state."
  @spec status(String.t()) :: {:ok, Snapshot.t()} | {:error, term()}
  def status(run_id) do
    with {:ok, pid} <- lookup(run_id) do
      {:ok, :gen_statem.call(pid, :status)}
    end
  end

  @doc "Approves an approval gate (label must exist on the current state's `on` map)."
  @spec approve(String.t(), atom()) :: :ok | {:error, term()}
  def approve(run_id, label) do
    with {:ok, pid} <- lookup(run_id) do
      :gen_statem.call(pid, {:approve, label})
    end
  end

  @doc "Cancels a run when the program defines a `:failed` final state."
  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(run_id) do
    with {:ok, pid} <- lookup(run_id) do
      :gen_statem.call(pid, :cancel)
    end
  end

  @doc "Continues an in-flight run until final, approval, or error."
  @spec resume(String.t(), keyword()) :: :ok | {:error, term()}
  def resume(run_id, opts \\ []), do: drive(run_id, opts)

  @doc "Executes the active node, classifies the result, and transitions the engine."
  @spec step(String.t(), keyword()) :: :ok | {:error, term()} | :retry
  def step(run_id, opts \\ []) do
    with {:ok, pid} <- lookup(run_id),
         {:ok, snapshot} <- {:ok, :gen_statem.call(pid, :status)},
         true <- snapshot.state_type == :active,
         {:ok, node} <- Program.active_node(snapshot.program, snapshot.current_state),
         executor = Keyword.get(opts, :executor, ExecutorRouter.module_for(node)),
         {:ok, raw} <- executor.execute(node, snapshot.run_context),
         outcome <- Evaluator.evaluate(node, raw),
         reply <- :gen_statem.call(pid, {:node_finished, outcome}) do
      normalize_step_reply(reply)
    else
      false -> {:error, :not_active}
      {:error, _} = err -> err
    end
  end

  defp start_program(%Program{} = program, opts) do
    run_id = Keyword.get(opts, :run_id, unique_run_id())
    workspace = Keyword.get(opts, :workspace_root, File.cwd!())

    ctx = %RunContext{
      run_id: run_id,
      workspace_root: workspace,
      env: Map.new(Keyword.get(opts, :env, []))
    }

    child =
      {Engine,
       [
         program: program,
         run_context: ctx,
         name: {:via, Registry, {@registry, run_id}}
       ]}

    case DynamicSupervisor.start_child(@supervisor, child) do
      {:ok, pid} ->
        case maybe_start(pid, program) do
          :ok ->
            {:ok, run_id}

          {:error, _} = err ->
            DynamicSupervisor.terminate_child(@supervisor, pid)
            err
        end

      {:error, _} = err ->
        err
    end
  end

  defp drive(run_id, opts) do
    case status(run_id) do
      {:ok, %Snapshot{done: true}} ->
        :ok

      {:ok, %Snapshot{state_type: :active}} ->
        case step(run_id, opts) do
          :ok -> drive(run_id, opts)
          :retry -> drive(run_id, opts)
          {:error, _} = err -> err
        end

      {:ok, %Snapshot{state_type: :approval}} ->
        {:error, :awaiting_approval}

      {:ok, _} ->
        {:error, :stuck}

      {:error, _} = err ->
        err
    end
  end

  defp lookup(run_id) do
    case Registry.lookup(@registry, run_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  defp normalize_step_reply(:ok), do: :ok
  defp normalize_step_reply(:retry), do: :retry
  defp normalize_step_reply({:error, _} = err), do: err
  defp normalize_step_reply(other), do: other

  defp unique_run_id do
    "run-" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  defp maybe_start(pid, %Program{initial: initial, states: states}) do
    case Map.get(states, initial) do
      %Orchestrator.Domain.StateDefinition{type: :passive} ->
        :gen_statem.call(pid, {:start, :default})

      _ ->
        :ok
    end
  end
end
