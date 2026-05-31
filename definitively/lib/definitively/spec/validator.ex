defmodule Definitively.Spec.Validator do

  alias Definitively.Log
  @moduledoc "Cross-checks on a loaded `Program` before execution."

  alias Definitively.Domain.{Program, StateDefinition}
  alias Definitively.Spec.Error

  @doc "Runs structural validation checks on a loaded program."
  @spec validate(Program.t()) :: :ok | {:error, Error.t()}
  def validate(%Program{} = program) do
    Log.trace("validating program", program_id: program.id)
    [
      &validate_initial/1,
      &validate_state_transitions/1,
      &validate_active_node_refs/1,
      &validate_final_states/1,
      &validate_reachable_finals/1
    ]
    |> Enum.reduce_while(:ok, fn check, :ok ->
      case check.(program) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp validate_initial(%Program{initial: initial, states: states}) do
    if Map.has_key?(states, initial) do
      :ok
    else
      {:error, Error.new(:invalid_initial, "initial state #{inspect(initial)} is not defined")}
    end
  end

  defp validate_state_transitions(%Program{states: states}) do
    states
    |> Enum.reduce(:ok, fn {name, %StateDefinition{on: on}}, acc ->
      if acc != :ok, do: acc, else: check_on_targets(name, on, states)
    end)
  end

  defp check_on_targets(from, on, states) do
    Enum.find_value(on, :ok, fn {_label, target} ->
      if Map.has_key?(states, target) do
        nil
      else
        {:error,
         Error.new(
           :invalid_transition,
           "state #{inspect(from)} transitions to undefined state #{inspect(target)}"
         )}
      end
    end) || :ok
  end

  defp validate_active_node_refs(%Program{states: states, nodes: nodes}) do
    states
    |> Enum.reduce(:ok, fn {name, %StateDefinition{type: type, node: node_id}}, acc ->
      cond do
        acc != :ok ->
          acc

        type == :active and is_nil(node_id) ->
          {:error,
           Error.new(:missing_node_ref, "active state #{inspect(name)} must declare node")}

        type == :active and not Map.has_key?(nodes, node_id) ->
          {:error,
           Error.new(
             :undefined_node,
             "state #{inspect(name)} references undefined node #{inspect(node_id)}"
           )}

        true ->
          :ok
      end
    end)
  end

  defp validate_final_states(%Program{} = program) do
    case Program.final_states(program) do
      [] ->
        {:error, Error.new(:no_final_state, "program must define at least one final state")}

      _ ->
        :ok
    end
  end

  defp validate_reachable_finals(%Program{initial: initial, states: states}) do
    finals = MapSet.new(for {n, %{type: :final}} <- states, do: n)
    reachable = reachable_states(initial, states)

    if MapSet.disjoint?(reachable, finals) do
      {:error,
       Error.new(
         :unreachable_final,
         "no final state is reachable from initial #{inspect(initial)}"
       )}
    else
      :ok
    end
  end

  defp reachable_states(start, states) do
    do_reachable(MapSet.new([start]), :queue.from_list([start]), states)
  end

  defp do_reachable(visited, queue, states) do
    case :queue.out(queue) do
      {{:value, current}, rest} ->
        nexts =
          case Map.get(states, current) do
            %StateDefinition{on: on} -> Map.values(on)
            nil -> []
          end

        unvisited = Enum.reject(nexts, &MapSet.member?(visited, &1))

        new_visited =
          Enum.reduce(unvisited, visited, fn state, acc -> MapSet.put(acc, state) end)

        new_queue = Enum.reduce(unvisited, rest, fn state, q -> :queue.in(state, q) end)

        do_reachable(new_visited, new_queue, states)

      {:empty, _} ->
        visited
    end
  end
end
