defmodule Definitively.CLI.InputParser do
  @moduledoc "Parses CLI flags for declared program inputs."

  alias Definitively.Domain.{Program, ProgramInput}

  @type parse_error ::
          {:unknown_flag, String.t(), [String.t()]}
          | {:missing_required, [String.t()]}
          | {:duplicate_flag, String.t()}
          | {:missing_value, String.t()}

  @doc """
  Parses argv after the program path into a string-keyed input map.

  Applies defaults, expands path inputs relative to `workspace_root`, and
  validates required inputs before the FSM starts.
  """
  @spec parse([String.t()], Program.t(), Path.t()) :: {:ok, map()} | {:error, parse_error()}
  def parse(argv, %Program{} = program, workspace_root) do
    declared = program.inputs || %{}

    with {:ok, raw} <- parse_flags(argv, declared),
         {:ok, merged} <- merge_defaults(raw, declared),
         {:ok, resolved} <- resolve_types(merged, declared, workspace_root),
         :ok <- validate_required(resolved, declared) do
      {:ok, resolved}
    end
  end

  @doc "Returns help lines for declared program inputs."
  @spec help_lines(Program.t()) :: [String.t()]
  def help_lines(%Program{inputs: inputs}) when map_size(inputs) == 0 do
    ["  (no declared inputs)"]
  end

  def help_lines(%Program{inputs: inputs}) do
    inputs
    |> Map.values()
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&format_help_line/1)
  end

  defp parse_flags([], _declared), do: {:ok, %{}}

  defp parse_flags(argv, declared) do
    known_flags =
      declared
      |> Map.keys()
      |> Map.new(fn name -> {ProgramInput.flag(name), name} end)

    do_parse_flags(argv, known_flags, %{})
  end

  defp do_parse_flags([], _known_flags, acc), do: {:ok, acc}

  defp do_parse_flags([arg | rest], known_flags, acc) do
    cond do
      match?("--" <> _, arg) and String.contains?(arg, "=") ->
        [flag, value] = String.split(arg, "=", parts: 2)
        consume_flag(flag, value, rest, known_flags, acc)

      match?("--" <> _, arg) ->
        case rest do
          [<<"--", _::binary>> | _] ->
            {:error, {:missing_value, arg}}

          [value | tail] ->
            consume_flag(arg, value, tail, known_flags, acc)

          _ ->
            {:error, {:missing_value, arg}}
        end

      true ->
        {:error, {:unknown_flag, arg, Map.keys(known_flags)}}
    end
  end

  defp consume_flag(flag, value, rest, known_flags, acc) do
    case Map.get(known_flags, flag) do
      nil ->
        {:error, {:unknown_flag, flag, Map.keys(known_flags)}}

      name ->
        key = Atom.to_string(name)

        if Map.has_key?(acc, key) do
          {:error, {:duplicate_flag, flag}}
        else
          do_parse_flags(rest, known_flags, Map.put(acc, key, value))
        end
    end
  end

  defp merge_defaults(raw, declared) do
    defaults =
      declared
      |> Map.values()
      |> Enum.reject(& &1.required)
      |> Enum.reduce(%{}, fn %ProgramInput{name: name, default: default}, acc ->
        if is_nil(default), do: acc, else: Map.put(acc, Atom.to_string(name), default)
      end)

    {:ok, Map.merge(defaults, raw)}
  end

  defp resolve_types(values, declared, workspace_root) do
    values
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      name = String.to_atom(key)

      case Map.get(declared, name) do
        %ProgramInput{type: :path} ->
          {:cont, {:ok, Map.put(acc, key, Path.expand(value, workspace_root))}}

        %ProgramInput{type: :string} ->
          {:cont, {:ok, Map.put(acc, key, value)}}

        nil ->
          {:cont, {:ok, Map.put(acc, key, value)}}
      end
    end)
  end

  defp validate_required(values, declared) do
    missing =
      declared
      |> Map.values()
      |> Enum.filter(& &1.required)
      |> Enum.reject(fn %ProgramInput{name: name} ->
        value = Map.get(values, Atom.to_string(name))
        is_binary(value) and value != ""
      end)
      |> Enum.map(fn %ProgramInput{name: name} -> ProgramInput.flag(name) end)

    if missing == [] do
      :ok
    else
      {:error, {:missing_required, missing}}
    end
  end

  defp format_help_line(%ProgramInput{} = input) do
    req =
      if input.required,
        do: "required",
        else: "optional" <> default_suffix(input.default)

    type = Atom.to_string(input.type)
    desc = if input.description, do: "  #{input.description}", else: ""

    "  #{ProgramInput.flag(input.name)}  (#{req}, #{type})#{desc}"
  end

  defp default_suffix(nil), do: ""
  defp default_suffix(default), do: ", default: #{default}"
end
