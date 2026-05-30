defmodule Orchestrator.Domain.Program do
  @moduledoc "Immutable workflow definition loaded from YAML."

  alias Orchestrator.Domain.{NodeDefinition, StateDefinition}

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          initial: atom(),
          states: %{atom() => StateDefinition.t()},
          nodes: %{atom() => NodeDefinition.t()}
        }

  defstruct [:id, :version, :initial, :states, :nodes]

  @spec active_node(t(), atom()) :: {:ok, NodeDefinition.t()} | {:error, :not_active}
  def active_node(%__MODULE__{states: states, nodes: nodes}, state_name) do
    case Map.get(states, state_name) do
      %StateDefinition{type: :active, node: node_id} when not is_nil(node_id) ->
        case Map.get(nodes, node_id) do
          nil -> {:error, :not_active}
          node -> {:ok, node}
        end

      _ ->
        {:error, :not_active}
    end
  end

  @spec final_states(t()) :: [atom()]
  def final_states(%__MODULE__{states: states}) do
    states
    |> Enum.filter(fn {_name, %StateDefinition{type: type}} -> type == :final end)
    |> Enum.map(fn {name, _} -> name end)
  end
end
