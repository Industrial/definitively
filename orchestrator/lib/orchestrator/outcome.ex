defmodule Orchestrator.Outcome do
  @moduledoc """
  Rich outcome for workflow nodes (CLI, LLM, git, …).

  Evaluators produce these values; the FSM transitions on `status`, not raw exit codes.
  """

  @type status :: :success | :failure | :partial | :unknown

  @type t :: %__MODULE__{
          status: status(),
          verdict_label: atom() | nil,
          exit_code: non_neg_integer() | nil,
          signals: map(),
          artifacts: map(),
          raw: map()
        }

  defstruct status: :unknown,
            verdict_label: nil,
            exit_code: nil,
            signals: %{},
            artifacts: %{},
            raw: %{}

  @doc false
  @spec success(keyword()) :: t()
  def success(opts \\ []) do
    struct!(__MODULE__, Keyword.put(opts, :status, :success))
  end

  @doc false
  @spec failure(keyword()) :: t()
  def failure(opts \\ []) do
    struct!(__MODULE__, Keyword.put(opts, :status, :failure))
  end
end
