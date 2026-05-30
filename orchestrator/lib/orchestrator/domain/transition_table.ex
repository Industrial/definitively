defmodule Orchestrator.Domain.TransitionTable do
  @moduledoc "Pure transition lookup built from a program's `states.*.on` maps."

  alias Orchestrator.Domain.Program

  @type edge :: {atom(), atom()}
  @type t :: %__MODULE__{edges: %{edge() => atom()}}

  defstruct edges: %{}

  @spec build(Program.t()) :: t()
  def build(%Program{states: states}) do
    edges =
      Enum.reduce(states, %{}, fn {from_state, state_def}, acc ->
        Enum.reduce(state_def.on, acc, fn {label, to_state}, inner ->
          Map.put(inner, {from_state, label}, to_state)
        end)
      end)

    %__MODULE__{edges: edges}
  end

  @spec next(t(), atom(), atom()) :: {:ok, atom()} | {:error, :no_transition}
  def next(%__MODULE__{edges: edges}, from_state, label) do
    case Map.get(edges, {from_state, label}) do
      nil -> {:error, :no_transition}
      to_state -> {:ok, to_state}
    end
  end
end
