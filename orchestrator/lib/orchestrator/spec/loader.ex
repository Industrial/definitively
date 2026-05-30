defmodule Orchestrator.Spec.Loader do
  @moduledoc "Load YAML workflow programs into `Orchestrator.Domain.Program`."

  alias Orchestrator.Domain.{NodeDefinition, Program, StateDefinition}
  alias Orchestrator.Log
  alias Orchestrator.Spec.{Error, Validator}

  @doc """
  Reads and validates a YAML workflow file into a `Program`.

  Returns `{:ok, program}` or `{:error, %Error{}}`.
  """
  @spec load(Path.t()) :: {:ok, Program.t()} | {:error, Error.t()}
  def load(path) do
    Log.debug("loading program", path: path)

    with {:ok, raw} <- read_yaml(path),
         {:ok, program} <- build_program(raw, path),
         :ok <- Validator.validate(program) do
      Log.info("program loaded",
        path: path,
        program_id: program.id,
        version: program.version,
        states: map_size(program.states),
        nodes: map_size(program.nodes)
      )

      {:ok, program}
    else
      {:error, %Error{} = err} ->
        Log.error("program load failed", path: path, error: err.message)
        {:error, err}

      {:error, reason} ->
        Log.error("program load failed", path: path, error: inspect(reason))
        {:error, reason}
    end
  end

  defp read_yaml(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:error, reason} ->
        {:error, Error.new(:invalid_yaml, "failed to parse YAML: #{inspect(reason)}", path)}
    end
  end

  defp build_program(raw, path) do
    with {:ok, meta} <- fetch_program_meta(raw, path),
         {:ok, states} <- parse_states(Map.get(raw, "states"), path),
         {:ok, nodes} <- parse_nodes(Map.get(raw, "nodes"), path) do
      {:ok,
       %Program{
         id: meta.id,
         version: meta.version,
         initial: meta.initial,
         states: states,
         nodes: nodes
       }}
    end
  end

  defp fetch_program_meta(raw, path) do
    case Map.get(raw, "program") do
      %{"id" => id, "version" => version, "initial" => initial}
      when is_binary(id) and is_integer(version) and is_binary(initial) ->
        with {:ok, initial_atom} <- atom_or_error(initial, path, "program.initial") do
          {:ok, %{id: id, version: version, initial: initial_atom}}
        end

      _ ->
        {:error,
         Error.new(
           :invalid_program,
           "program must include id, version, and initial",
           path
         )}
    end
  end

  defp parse_states(nil, path),
    do: {:error, Error.new(:missing_states, "states section is required", path)}

  defp parse_states(states, path) when is_map(states) do
    states
    |> Enum.reduce_while({:ok, %{}}, fn {name, defn}, {:ok, acc} ->
      case parse_state(name, defn, path) do
        {:ok, state} -> {:cont, {:ok, Map.put(acc, state.name, state)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp parse_states(_, path),
    do: {:error, Error.new(:invalid_states, "states must be a map", path)}

  defp parse_state(name, defn, path) when is_map(defn) do
    with {:ok, state_name} <- atom_or_error(name, path, "states.#{name}"),
         {:ok, type} <- parse_state_type(Map.get(defn, "type"), path, name),
         {:ok, on} <- parse_on(Map.get(defn, "on", %{}), path, name),
         {:ok, node} <- parse_optional_node_ref(Map.get(defn, "node"), path, name) do
      {:ok,
       %StateDefinition{
         name: state_name,
         type: type,
         node: node,
         on: on,
         prompt: Map.get(defn, "prompt")
       }}
    end
  end

  defp parse_state(name, _, path),
    do: {:error, Error.new(:invalid_state, "state #{name} must be a map", path)}

  defp parse_state_type(type, _path, _name)
       when type in ["passive", "active", "approval", "final"],
       do: {:ok, String.to_atom(type)}

  defp parse_state_type(type, path, name),
    do:
      {:error,
       Error.new(
         :invalid_state_type,
         "state #{name} has invalid type #{inspect(type)}",
         path
       )}

  defp parse_on(on, _path, _name) when on == %{}, do: {:ok, %{}}

  defp parse_on(on, path, state_name) when is_map(on) do
    on
    |> Enum.reduce_while({:ok, %{}}, fn {label, target}, {:ok, acc} ->
      ctx_label = "states.#{state_name}.on.#{label}"
      ctx_target = "states.#{state_name}.on -> #{target}"

      with {:ok, label_atom} <- atom_or_error(label, path, ctx_label),
           {:ok, target_atom} <- atom_or_error(target, path, ctx_target) do
        {:cont, {:ok, Map.put(acc, label_atom, target_atom)}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp parse_on(_, path, name),
    do: {:error, Error.new(:invalid_on, "states.#{name}.on must be a map", path)}

  defp parse_optional_node_ref(nil, _path, _name), do: {:ok, nil}

  defp parse_optional_node_ref(node_id, path, name) when is_binary(node_id),
    do: atom_or_error(node_id, path, "states.#{name}.node")

  defp parse_optional_node_ref(_node_id, path, name),
    do: {:error, Error.new(:invalid_node_ref, "states.#{name}.node must be a string", path)}

  defp parse_nodes(nil, _path), do: {:ok, %{}}

  defp parse_nodes(nodes, path) when is_map(nodes) do
    nodes
    |> Enum.reduce_while({:ok, %{}}, fn {id, defn}, {:ok, acc} ->
      case parse_node(id, defn, path) do
        {:ok, node} -> {:cont, {:ok, Map.put(acc, node.id, node)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp parse_nodes(_, path),
    do: {:error, Error.new(:invalid_nodes, "nodes must be a map", path)}

  defp parse_node(id, defn, path) when is_map(defn) do
    with {:ok, node_id} <- atom_or_error(id, path, "nodes.#{id}"),
         {:ok, kind} <- parse_node_kind(Map.get(defn, "kind"), path, id),
         {:ok, command} <- parse_command(Map.get(defn, "command"), path, id),
         {:ok, outcome} <- parse_outcome(Map.get(defn, "outcome", %{}), path, id) do
      {:ok,
       %NodeDefinition{
         id: node_id,
         kind: kind,
         command: command,
         cwd: Map.get(defn, "cwd"),
         timeout_ms: Map.get(defn, "timeout_ms"),
         model: Map.get(defn, "model"),
         prompt_file: Map.get(defn, "prompt_file"),
         outcome: outcome
       }}
    end
  end

  defp parse_node(id, _, path),
    do: {:error, Error.new(:invalid_node, "node #{id} must be a map", path)}

  defp parse_node_kind(kind, _path, _id) when kind in ["cli", "llm"],
    do: {:ok, String.to_atom(kind)}

  defp parse_node_kind(_kind, path, id),
    do: {:error, Error.new(:invalid_node_kind, "nodes.#{id}.kind must be cli or llm", path)}

  defp parse_command(nil, _path, _id), do: {:ok, nil}
  defp parse_command(cmd, _path, _id) when is_list(cmd), do: {:ok, Enum.map(cmd, &to_string/1)}

  defp parse_command(_cmd, path, id),
    do: {:error, Error.new(:invalid_command, "nodes.#{id}.command must be a list", path)}

  defp reduce_outcome_label({label, clauses}, {:ok, acc}, path, id) do
    with {:ok, parsed} <- parse_outcome_clauses(clauses, path, id, label),
         {:ok, label_atom} <- atom_or_error(label, path, "nodes.#{id}.outcome.#{label}") do
      {:cont, {:ok, Map.put(acc, label_atom, parsed)}}
    else
      {:error, _} = err -> {:halt, err}
    end
  end

  defp parse_outcome(outcome, path, id) when is_map(outcome) do
    Enum.reduce_while(outcome, {:ok, %{}}, &reduce_outcome_label(&1, &2, path, id))
  end

  defp parse_outcome(_, path, id),
    do: {:error, Error.new(:invalid_outcome, "nodes.#{id}.outcome must be a map", path)}

  defp parse_outcome_clauses(clauses, path, id, label) when is_list(clauses) do
    clauses
    |> Enum.reduce_while({:ok, []}, fn clause, {:ok, acc} ->
      case parse_predicate_clause(clause, path, id, label) do
        {:ok, pred} -> {:cont, {:ok, acc ++ [pred]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp parse_outcome_clauses(_, path, id, label),
    do:
      {:error,
       Error.new(
         :invalid_outcome_clauses,
         "nodes.#{id}.outcome.#{label} must be a list",
         path
       )}

  defp parse_predicate_clause(clause, _path, _id, _label) when is_map(clause),
    do: {:ok, normalize_predicate(clause)}

  defp parse_predicate_clause(_, path, id, label),
    do:
      {:error,
       Error.new(
         :invalid_predicate,
         "nodes.#{id}.outcome.#{label} clauses must be maps",
         path
       )}

  defp normalize_predicate(clause) do
    clause
    |> Enum.map(fn
      {"exit_code", value} -> {:exit_code, value}
      {"timeout", value} -> {:timeout, value}
      {"signal", value} -> {:signal, value}
      {"jq", value} -> {:jq, value}
      {key, value} -> {String.to_atom(key), value}
    end)
    |> Map.new()
  end

  defp atom_or_error(value, _path, _ctx) when is_atom(value), do: {:ok, value}

  defp atom_or_error(value, _path, _ctx) when is_binary(value), do: {:ok, String.to_atom(value)}

  defp atom_or_error(value, path, ctx),
    do: {:error, Error.new(:invalid_atom, "#{ctx} must be a string, got #{inspect(value)}", path)}
end
