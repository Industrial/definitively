defmodule Definitively.Domain.NodeDefinition do
  @moduledoc "Reusable node referenced by active states."

  @type kind :: :cli | :llm | :git | :gh
  @type predicate :: map()
  @type outcome_clause :: %{atom() => [predicate()]}

  @type t :: %__MODULE__{
          id: atom(),
          kind: kind(),
          command: [String.t()] | nil,
          action: atom() | nil,
          options: map() | nil,
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
    :action,
    :options,
    :cwd,
    :timeout_ms,
    :model,
    :prompt_file,
    outcome: %{}
  ]

  @kinds ~w(cli llm git gh)a

  @git_actions ~w(status diff add commit push tag)a
  @gh_actions ~w(pr_create pr_view run_list run_watch run_view)a

  @doc """
  Returns supported node kinds.

      iex> Definitively.Domain.NodeDefinition.kinds()
      [:cli, :llm, :git, :gh]
  """
  @spec kinds() :: [kind()]
  def kinds, do: @kinds

  @doc "Returns supported git node actions."
  @spec git_actions() :: [atom()]
  def git_actions, do: @git_actions

  @doc "Returns supported gh node actions."
  @spec gh_actions() :: [atom()]
  def gh_actions, do: @gh_actions
end
