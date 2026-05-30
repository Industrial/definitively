defmodule Orchestrator.Domain.StateDefinition do
  @moduledoc "One FSM state from a workflow program."

  @type state_type :: :passive | :active | :approval | :final

  @type t :: %__MODULE__{
          name: atom(),
          type: state_type(),
          node: atom() | nil,
          on: %{atom() => atom()},
          prompt: String.t() | nil
        }

  defstruct [:name, :type, :node, :on, :prompt]

  @state_types ~w(passive active approval final)a

  @doc "Returns all supported FSM state types."
  @spec types() :: [state_type()]
  def types, do: @state_types
end
