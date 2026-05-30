defmodule Orchestrator.Outcome do
  @moduledoc """
  Rich outcome for workflow nodes (CLI, LLM, git, …).

  Evaluators produce these values; the FSM transitions on `status`, not raw exit codes.
  """

  @type status :: :success | :failure | :partial | :unknown

  @type t :: %__MODULE__{
          status: status(),
          exit_code: non_neg_integer() | nil,
          signals: map(),
          artifacts: map()
        }

  defstruct status: :unknown,
            exit_code: nil,
            signals: %{},
            artifacts: %{}

  @doc false
  def success(opts \\ []) do
    struct!(__MODULE__, Keyword.put(opts, :status, :success))
  end

  @doc false
  def failure(opts \\ []) do
    struct!(__MODULE__, Keyword.put(opts, :status, :failure))
  end
end
