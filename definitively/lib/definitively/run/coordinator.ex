defmodule Definitively.Run.Coordinator do
  @moduledoc """
  Application facade for starting and controlling ephemeral workflow runs.
  """

  alias Definitively.Domain.{Program, StateDefinition}
  alias Definitively.Log
  alias Definitively.Nodes.ExecutorRouter
  alias Definitively.Outcome.Evaluator
  alias Definitively.Run.Snapshot
  alias Definitively.Spec.Loader
  alias Definitively.Workflow.{Engine, RunContext}

  @registry Definitively.Run.Registry
  @supervisor Definitively.Run.EngineSupervisor

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
    Log.info("starting run", path: program_path)

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
         :ok <- log_executing_node(run_id, snapshot, node),
         executor = Keyword.get(opts, :executor, ExecutorRouter.module_for(node)),
         {:ok, raw} <- executor.execute(node, snapshot.run_context),
         outcome = Evaluator.evaluate(node, raw),
         :ok <- log_node_outcome(run_id, node, outcome),
         reply <- :gen_statem.call(pid, {:node_finished, outcome}) do
      log_step_reply(run_id, snapshot.current_state, reply)
      normalize_step_reply(reply)
    else
      false ->
        Log.warn("step called while run not active", run_id: run_id)
        {:error, :not_active}

      {:error, _} = err ->
        Log.error("step failed", run_id: run_id, error: inspect(err))
        err
    end
  end

  defp log_executing_node(run_id, snapshot, node) do
    Log.info("executing node",
      run_id: run_id,
      state: snapshot.current_state,
      node_id: node.id,
      kind: node.kind
    )

    :ok
  end

  defp log_node_outcome(run_id, node, outcome) do
    Log.info("node outcome",
      run_id: run_id,
      node_id: node.id,
      status: outcome.status,
      label: outcome.verdict_label,
      exit_code: outcome.exit_code
    )

    :ok
  end

  defp log_step_reply(run_id, state, :ok) do
    Log.debug("step completed", run_id: run_id, state: state)
    :ok
  end

  defp log_step_reply(run_id, state, :retry) do
    Log.info("step retry", run_id: run_id, state: state)
    :ok
  end

  defp log_step_reply(run_id, state, {:error, reason}) do
    Log.warn("step engine reply error", run_id: run_id, state: state, error: inspect(reason))
    :ok
  end

  defp log_step_reply(_run_id, _state, _reply), do: :ok

  defp start_program(%Program{} = program, opts) do
    run_id = Keyword.get(opts, :run_id, unique_run_id())
    workspace =
      Keyword.get(opts, :workspace_root) ||
        System.get_env("DEFINITIVELY_WORKSPACE") ||
        File.cwd!()

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
            Log.info("run started",
              run_id: run_id,
              program_id: program.id,
              workspace: workspace
            )

            {:ok, run_id}

          {:error, _} = err ->
            Log.error("run failed to start workflow", run_id: run_id, error: inspect(err))
            DynamicSupervisor.terminate_child(@supervisor, pid)
            err
        end

      {:error, _} = err ->
        err
    end
  end

  defp drive(run_id, opts) do
    case status(run_id) do
      {:ok, snap} -> drive_snapshot(run_id, opts, snap)
      {:error, _} = err -> err
    end
  end

  defp drive_snapshot(run_id, _opts, %Snapshot{done: true}) do
    Log.info("run finished", run_id: run_id, state: :done)
    :ok
  end

  defp drive_snapshot(run_id, opts, %Snapshot{state_type: :active} = snap) do
    Log.debug("driving active state", run_id: run_id, state: snap.current_state)

    case step(run_id, opts) do
      :ok -> drive(run_id, opts)
      :retry -> drive(run_id, opts)
      {:error, _} = err -> err
    end
  end

  defp drive_snapshot(run_id, opts, %Snapshot{state_type: :approval} = snap) do
    drive_approval(run_id, opts, snap)
  end

  defp drive_snapshot(run_id, _opts, snap) do
    Log.error("run stuck in non-active state",
      run_id: run_id,
      state: snap.current_state,
      state_type: snap.state_type
    )

    {:error, :stuck}
  end

  defp drive_approval(run_id, opts, snap) do
    case auto_approval_label(snap) do
      {:ok, label} ->
        Log.info("auto-approving gate",
          run_id: run_id,
          state: snap.current_state,
          label: label,
          prompt: snap.approval_prompt
        )

        with :ok <- approve(run_id, label), do: drive(run_id, opts)

      {:error, reason} ->
        Log.error("run stuck at approval without auto label",
          run_id: run_id,
          state: snap.current_state,
          reason: reason
        )

        {:error, :awaiting_approval}
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

  defp auto_approval_label(%Snapshot{program: %Program{states: states}, current_state: state}) do
    case Map.get(states, state) do
      %StateDefinition{type: :approval, on: on} when map_size(on) > 0 ->
        label =
          cond do
            Map.has_key?(on, :approve) -> :approve
            Map.has_key?(on, :done) -> :done
            true -> on |> Map.keys() |> Enum.reject(&(&1 == :reject)) |> List.first()
          end

        if label, do: {:ok, label}, else: {:error, :no_approval_label}

      _ ->
        {:error, :not_approval}
    end
  end

  defp maybe_start(pid, %Program{initial: initial, states: states}) do
    case Map.get(states, initial) do
      %Definitively.Domain.StateDefinition{type: :passive} ->
        :gen_statem.call(pid, {:start, :default})

      _ ->
        :ok
    end
  end
end
