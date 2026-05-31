defmodule Definitively.Domain.NodeDefinition do
  @moduledoc "Reusable node (CLI or LLM) referenced by active states."

  @type kind :: :cli | :llm
  @type predicate :: map()
  @type outcome_clause :: %{atom() => [predicate()]}

  @type t :: %__MODULE__{
          id: atom(),
          kind: kind(),
          command: [String.t()] | nil,
          cwd: String.t() | nil,
          timeout_ms: pos_integer() | nil,
          model: String.t() | nil,
          prompt_file: String.t() | nil,
          outcome: outcome_clause()
        }

  defstruct [
    :id,
    :kind,
    :command,
    :cwd,
    :timeout_ms,
    :model,
    :prompt_file,
    outcome: %{}
  ]

  @kinds ~w(cli llm)a

  @doc """
  Returns supported node kinds.

      iex> Definitively.Domain.NodeDefinition.kinds()
      [:cli, :llm]
  """
  @spec kinds() :: [kind()]
  def kinds, do: @kinds
end
