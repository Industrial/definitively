defmodule Orchestrator.Workflow.Engine do
  @moduledoc """
  Data-driven workflow runner as `:gen_statem`.

  States and transitions come from a loaded `Orchestrator.Domain.Program`.
  Node execution is external in v1 — callers send `{:node_result, outcome}` or
  `{:node_finished, outcome}` after running a node.
  """

  @behaviour :gen_statem

  alias Orchestrator.Domain.{Program, StateDefinition, TransitionTable}
  alias Orchestrator.Outcome
  alias Orchestrator.Run.Snapshot
  alias Orchestrator.Spec.Loader
  alias Orchestrator.Workflow.RunContext

  @fixture_path Path.expand("../../../test/fixtures/dev_quality_loop.yml", __DIR__)

  @type data :: %{
          program: Program.t(),
          table: TransitionTable.t(),
          run_context: RunContext.t() | nil,
          history: [map()],
          attempts: %{atom() => non_neg_integer()}
        }

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  @doc false
  @spec start_link(keyword()) :: :gen_statem.start_ret()
  def start_link(opts \\ []) do
    program = Keyword.get_lazy(opts, :program, &load_default_program!/0)
    init_args = [program: program, run_context: Keyword.get(opts, :run_context)]

    case Keyword.get(opts, :name, __MODULE__) do
      {:via, Registry, {registry, key}} ->
        :gen_statem.start_link({:via, Registry, {registry, key}}, __MODULE__, init_args, [])

      name ->
        :gen_statem.start_link({:local, name}, __MODULE__, init_args, [])
    end
  end

  @impl :gen_statem
  @doc false
  def callback_mode, do: :handle_event_function

  @impl :gen_statem
  @doc false
  def init(opts) when is_list(opts) do
    program =
      opts
      |> Keyword.get(:program)
      |> case do
        %Program{} = program -> program
        _ -> load_default_program!()
      end

    table = TransitionTable.build(program)
    run_context = Keyword.get(opts, :run_context)

    {:ok, program.initial,
     %{
       program: program,
       table: table,
       run_context: run_context,
       history: [],
       attempts: %{}
     }}
  end

  @impl :gen_statem
  @doc false
  def handle_event({:call, from}, {:start, _workflow}, state, data) do
    with %StateDefinition{type: :passive} <- state_def(data, state),
         {:ok, next} <- TransitionTable.next(data.table, state, :start) do
      {:next_state, next, record(data, state, :start, next), [{:reply, from, :ok}]}
    else
      _ -> {:keep_state_and_data, [{:reply, from, {:error, :invalid_start}}]}
    end
  end

  def handle_event({:call, from}, {:node_result, outcome}, state, data) do
    handle_node_finished(from, state, data, outcome)
  end

  def handle_event({:call, from}, {:node_finished, outcome}, state, data) do
    handle_node_finished(from, state, data, outcome)
  end

  def handle_event({:call, from}, {:approve, label}, state, data) do
    with %StateDefinition{type: :approval} <- state_def(data, state),
         {:ok, next} <- TransitionTable.next(data.table, state, label) do
      {:next_state, next, record(data, state, label, next), [{:reply, from, :ok}]}
    else
      _ -> {:keep_state_and_data, [{:reply, from, {:error, :invalid_approve}}]}
    end
  end

  def handle_event({:call, from}, :cancel, _state, data) do
    case final_on_cancel(data) do
      {:ok, next} ->
        {:next_state, next, record(data, :cancel, :cancel, next), [{:reply, from, :ok}]}

      :error ->
        {:keep_state_and_data, [{:reply, from, {:error, :cannot_cancel}}]}
    end
  end

  def handle_event({:call, from}, :status, state, data) do
    {:keep_state_and_data, [{:reply, from, snapshot(state, data)}]}
  end

  def handle_event({:call, from}, :noop, state, data) do
    case state_def(data, state) do
      %StateDefinition{type: :final} ->
        reply = if state == :failed, do: :failed, else: :finished
        {:keep_state_and_data, [{:reply, from, reply}]}

      _ ->
        {:keep_state_and_data, [{:reply, from, {:error, :not_final}}]}
    end
  end

  def handle_event(_event_type, _event, _state, _data), do: :keep_state_and_data

  @doc "Loads the `dev_quality_loop` fixture program from `test/fixtures`."
  @spec load_default_program!() :: Program.t()
  def load_default_program! do
    case Loader.load(@fixture_path) do
      {:ok, program} -> program
      {:error, err} -> raise "default program load failed: #{inspect(err)}"
    end
  end

  defp handle_node_finished(from, state, data, %Outcome{} = outcome) do
    case state_def(data, state) do
      %StateDefinition{type: :active} ->
        label = outcome_label(outcome)
        transition_active(from, state, data, label, outcome)

      _ ->
        {:keep_state_and_data, [{:reply, from, {:error, :not_active}}]}
    end
  end

  defp transition_active(from, state, data, label, outcome) do
    case TransitionTable.next(data.table, state, label) do
      {:ok, ^state} ->
        {:keep_state, bump_attempt(data, state), [{:reply, from, :retry}]}

      {:ok, next} ->
        reply = active_reply(state, label, outcome, next)
        {:next_state, next, record(data, state, label, next), [{:reply, from, reply}]}

      {:error, :no_transition} ->
        {:keep_state, data, [{:reply, from, {:error, :unknown_outcome}}]}
    end
  end

  defp active_reply(:commit, :failure, %Outcome{status: :failure}, :failed),
    do: {:error, :commit_failed}

  defp active_reply(_state, _label, _outcome, _next), do: :ok

  defp outcome_label(%Outcome{verdict_label: label}) when not is_nil(label), do: label

  defp outcome_label(%Outcome{status: status}) when status in [:success, :failure, :partial],
    do: status

  defp outcome_label(%Outcome{status: :unknown}), do: :unknown
  defp outcome_label(_), do: :unknown

  defp state_def(%{program: %{states: states}}, state) do
    Map.get(states, state)
  end

  defp record(data, from, label, to) do
    event = %{from: from, label: label, to: to, at: System.system_time(:millisecond)}
    %{data | history: data.history ++ [event]}
  end

  defp bump_attempt(data, state) do
    %{data | attempts: Map.update(data.attempts, state, 1, &(&1 + 1))}
  end

  defp snapshot(state, data) do
    defn = state_def(data, state)

    %Snapshot{
      run_id: data.run_context && data.run_context.run_id,
      program_id: data.program.id,
      program: data.program,
      run_context: data.run_context,
      current_state: state,
      state_type: defn && defn.type,
      approval_prompt: approval_prompt(defn),
      history: data.history,
      done: match?(%StateDefinition{type: :final}, defn)
    }
  end

  defp approval_prompt(%StateDefinition{type: :approval, prompt: prompt}), do: prompt
  defp approval_prompt(_), do: nil

  defp final_on_cancel(%{program: %{states: states}}) do
    case Map.get(states, :failed) do
      %StateDefinition{type: :final} -> {:ok, :failed}
      _ -> :error
    end
  end
end
