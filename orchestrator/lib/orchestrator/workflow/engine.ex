defmodule Orchestrator.Workflow.Engine do
  @moduledoc """
  Workflow runner as an OTP `:gen_statem`.

  Example lint/fix/commit loop:

      idle --start--> linting
      linting --failure--> fixing --success--> linting
      linting --success--> committing --success--> done
  """

  @behaviour :gen_statem

  alias Orchestrator.Outcome

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  @doc false
  def start_link(opts \\ []) do
    :gen_statem.start_link({:local, __MODULE__}, __MODULE__, opts, [])
  end

  @impl :gen_statem
  @doc false
  def callback_mode, do: :state_functions

  @impl :gen_statem
  @doc false
  def init(_opts), do: {:ok, :idle, %{attempt: 0}}

  @doc false
  def idle({:call, from}, {:start, _workflow}, data) do
    {:next_state, :linting, %{data | attempt: 1}, [{:reply, from, :ok}]}
  end

  @doc false
  def idle(_event, _content, _data), do: :keep_state_and_data

  @doc false
  def linting({:call, from}, {:node_result, %Outcome{status: :success}}, data) do
    {:next_state, :committing, data, [{:reply, from, :ok}]}
  end

  @doc false
  def linting({:call, from}, {:node_result, %Outcome{status: :failure}}, data) do
    {:next_state, :fixing, data, [{:reply, from, :ok}]}
  end

  @doc false
  def linting({:call, from}, {:node_result, _outcome}, data) do
    {:keep_state, data, [{:reply, from, {:error, :unknown_outcome}}]}
  end

  @doc false
  def linting(_event, _content, _data), do: :keep_state_and_data

  @doc false
  def fixing({:call, from}, {:node_result, %Outcome{status: :success}}, data) do
    {:next_state, :linting, data, [{:reply, from, :ok}]}
  end

  @doc false
  def fixing({:call, from}, {:node_result, _outcome}, data) do
    {:keep_state, data, [{:reply, from, :retry}]}
  end

  @doc false
  def fixing(_event, _content, _data), do: :keep_state_and_data

  @doc false
  def committing({:call, from}, {:node_result, %Outcome{status: :success}}, data) do
    {:next_state, :done, data, [{:reply, from, :ok}]}
  end

  @doc false
  def committing({:call, from}, _event, data) do
    {:keep_state, data, [{:reply, from, {:error, :commit_failed}}]}
  end

  @doc false
  def committing(_event, _content, _data), do: :keep_state_and_data

  @doc false
  def done({:call, from}, _event, data) do
    {:keep_state, data, [{:reply, from, :finished}]}
  end

  @doc false
  def done(_event, _content, _data), do: :keep_state_and_data
end
