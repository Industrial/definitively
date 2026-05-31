defmodule Definitively.Visualize do
  @moduledoc """
  Renders workflow programs as Graphviz graphs via Graphvix.

  Builds a directed graph from `Definitively.Domain.Program` states and transitions.
  """

  alias Definitively.Domain.{Program, StateDefinition}
  alias Definitively.Spec.Loader
  alias Definitively.Workspace
  alias Graphvix.Graph

  @default_format :dot
  @visualizations_dir ".definitively/visualizations"

  @type cli_mode :: :default | :single

  @type parsed_cli :: {cli_mode(), atom() | nil, String.t() | nil}

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
  @spec parse_cli_opts([String.t()]) :: parsed_cli()
  def parse_cli_opts(args) do
    case args do
      [] ->
        {:default, nil, nil}

      ["--format", fmt, "--out", path] ->
        {:single, parse_format(fmt), path}

      ["--format", fmt, path] ->
        {:single, parse_format(fmt), path}

      ["--format", fmt] ->
        {:single, parse_format(fmt), nil}

      ["--out", path] ->
        {:single, :dot, path}

      [fmt] when fmt in ["dot", "png", "svg"] ->
        {:single, parse_format(fmt), nil}

      _ ->
        {:single, @default_format, nil}
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
  CLI helper: render workflow visualizations under the workspace.

  Default mode writes DOT and PNG to `.definitively/visualizations/<basename>`.
  Single mode writes one format; omit `--out` to use the same default directory.
  """
  @spec cli_render(Path.t(), [String.t()]) :: {:ok, {:files, [String.t()]}} | {:error, term()}
  def cli_render(path, rest) do
    mode = parse_cli_opts(rest)

    case Workspace.resolve_run(path) do
      {:ok, resolved} ->
        cli_render_resolved(resolved, mode)

      {:error, :enoent} ->
        {:error, :invalid_program_path}

      {:error, :no_definitively_layout} ->
        {:error, :no_definitively_layout}

      {:error, reason} ->
        {:error, reason}
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

  defp cli_render_resolved(resolved, {:default, nil, nil}) do
    base = default_visualization_base(resolved)
    ensure_parent_dir!(base)

    with {:ok, graph} <- graph(resolved.program_path),
         {:ok, dot_path} <- write_dot(graph, base <> ".dot") do
      case compile_graph(graph, base, :png) do
        {:ok, png_path} ->
          {:ok, {:files, [dot_path, png_path]}}

        {:error, reason} ->
          {:error, {:graphviz_unavailable, reason, dot_path: dot_path}}
      end
    else
      {:error, %Definitively.Spec.Error{message: message}} -> {:error, message}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cli_render_resolved(resolved, {:single, format, out}) do
    base =
      case out do
        nil -> default_visualization_base(resolved)
        path -> output_base(path, resolved.program_path)
      end

    ensure_parent_dir!(base)

    with {:ok, graph} <- graph(resolved.program_path) do
      case write_format(graph, base, format) do
        {:ok, file_path} ->
          {:ok, {:files, [file_path]}}

        {:error, %Definitively.Spec.Error{message: message}} ->
          {:error, message}

        {:error, {:compile_failed, reason}} ->
          {:error, {:graphviz_unavailable, reason}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp write_format(graph, base, :dot) do
    write_dot(graph, base <> ".dot")
  end

  defp write_format(graph, base, fmt) when fmt in [:png, :svg] do
    compile_graph(graph, base, fmt)
  end

  defp write_format(_graph, _base, other) do
    {:error, {:invalid_format, other}}
  end

  defp write_dot(graph, path) do
    case File.write(path, Graph.to_dot(graph)) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp compile_graph(graph, base, fmt) do
    file = "#{base}.#{fmt}"

    try do
      {:ok, _} = Graph.compile(graph, base, fmt)
      {:ok, file}
    rescue
      exception -> {:error, {:compile_failed, exception}}
    end
  end

  defp default_visualization_base(%{workspace_root: root, program_path: program_path}) do
    Path.join([root, @visualizations_dir, default_out_base(program_path)])
  end

  defp ensure_parent_dir!(base) do
    base |> Path.dirname() |> File.mkdir_p!()
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
