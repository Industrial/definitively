defmodule Orchestrator.Visualize do
  @moduledoc """
  Renders workflow programs as Graphviz graphs via Graphvix.

  Builds a directed graph from `Orchestrator.Domain.Program` states and transitions.
  """

  alias Graphvix.Graph
  alias Orchestrator.Domain.{Program, StateDefinition}
  alias Orchestrator.Spec.Loader

  @default_format :dot

  @doc "Loads a YAML program and builds a Graphvix graph."
  @spec graph(Path.t()) :: {:ok, Graph.t()} | {:error, term()}
  def graph(path) do
    with {:ok, program} <- Loader.load(path) do
      {:ok, build(program)}
    end
  end

  @doc "Returns DOT source for a program file."
  @spec to_dot(Path.t()) :: {:ok, String.t()} | {:error, term()}
  def to_dot(path) do
    with {:ok, graph} <- graph(path) do
      {:ok, Graph.to_dot(graph)}
    end
  end

  @doc "Parses CLI flags after the program path."
  @spec parse_cli_opts([String.t()]) :: {atom(), String.t() | nil}
  def parse_cli_opts(args) do
    case args do
      ["--format", fmt, "--out", path] -> {parse_format(fmt), path}
      ["--format", fmt, path] -> {parse_format(fmt), path}
      ["--format", fmt] -> {parse_format(fmt), nil}
      ["--out", path] -> {:dot, path}
      [fmt] when fmt in ["dot", "png", "svg"] -> {parse_format(fmt), nil}
      [] -> {:dot, nil}
      _ -> {:dot, nil}
    end
  end

  @doc """
  Renders a program to DOT, PNG, or SVG.

  Options:
    * `:format` — `:dot`, `:png`, or `:svg`
    * `:out` — output path without extension
  """
  @spec render(Path.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(path, opts \\ []) do
    format = Keyword.get(opts, :format, @default_format)
    out = Keyword.get(opts, :out)

    with {:ok, graph} <- graph(path) do
      case format do
        :dot ->
          {:ok, Graph.to_dot(graph)}

        fmt when fmt in [:png, :svg] ->
          base = output_base(out, path)
          file = "#{base}.#{fmt}"

          try do
            {:ok, _} = Graph.compile(graph, base, fmt)
            {:ok, file}
          rescue
            exception -> {:error, {:compile_failed, exception}}
          end

        other ->
          {:error, {:invalid_format, other}}
      end
    end
  end

  @doc """
  CLI helper: render and classify output for printing.

  Returns `{:ok, {:stdout, dot}}`, `{:ok, {:file, path}}`, or `{:error, term()}`.
  """
  @spec cli_render(Path.t(), [String.t()]) :: {:ok, {:stdout, String.t()} | {:file, String.t()}} | {:error, term()}
  def cli_render(path, rest) do
    {format, out} = parse_cli_opts(rest)

    case render(path, format: format, out: out) do
      {:ok, content} when format == :dot -> {:ok, {:stdout, content}}
      {:ok, file} -> {:ok, {:file, file}}
      {:error, %Orchestrator.Spec.Error{message: message}} -> {:error, message}
      {:error, {:compile_failed, reason}} -> {:error, {:graphviz_unavailable, reason}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec build(Program.t()) :: Graph.t()
  def build(%Program{} = program) do
    {graph, ids} =
      program.states
      |> Enum.reduce({Graph.new(), %{}}, fn {name, defn}, {g, acc} ->
        attrs = state_attrs(defn, name == program.initial)
        {g, id} = Graph.add_vertex(g, state_label(defn), attrs)
        {g, Map.put(acc, name, id)}
      end)

    program.states
    |> Enum.reduce(graph, fn {from_name, %StateDefinition{on: on}}, g ->
      from_id = Map.fetch!(ids, from_name)

      Enum.reduce(on, g, fn {label, to_name}, acc ->
        to_id = Map.fetch!(ids, to_name)
        edge_label = Atom.to_string(label)
        {g2, _} = Graph.add_edge(acc, from_id, to_id, label: edge_label)
        g2
      end)
    end)
  end

  defp state_label(%StateDefinition{name: name, type: type, node: node_id}) do
    base = "#{name}\\n(#{type})"

    case node_id do
      nil -> base
      id -> base <> "\\n→ #{id}"
    end
  end

  defp state_attrs(%StateDefinition{type: type}, initial?) do
    base = [
      shape: state_shape(type),
      style: "filled",
      fillcolor: state_fillcolor(type),
      fontname: "Helvetica"
    ]

    if initial?, do: base ++ [penwidth: "3", color: "darkgreen"], else: base
  end

  defp state_shape(:final), do: "doublecircle"
  defp state_shape(:approval), do: "hexagon"
  defp state_shape(:passive), do: "ellipse"
  defp state_shape(:active), do: "box"

  defp state_fillcolor(:final), do: "lightgray"
  defp state_fillcolor(:approval), do: "orange"
  defp state_fillcolor(:passive), do: "lightblue"
  defp state_fillcolor(:active), do: "lightyellow"

  defp parse_format("dot"), do: :dot
  defp parse_format("png"), do: :png
  defp parse_format("svg"), do: :svg

  defp default_out_base(path) do
    path
    |> Path.basename()
    |> Path.rootname()
  end

  # Graphvix appends ".png" / ".svg"; strip a user-supplied extension to avoid ".png.png".
  defp output_base(nil, program_path), do: default_out_base(program_path)

  defp output_base(out, _program_path) when is_binary(out) do
    if Path.extname(out) in [".png", ".svg", ".dot"], do: Path.rootname(out), else: out
  end
end
