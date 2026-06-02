defmodule Definitively.TestCoverage do
  @moduledoc false

  alias LcovEx.{Formatter, Stats}
  alias Mix.Tasks.Test.Coverage

  @ignored_paths ["deps/"]

  @spec start(String.t(), keyword()) :: (-> :ok)
  @doc "Generates lcov output and enforces the Mix coverage threshold."
  def start(compile_path, opts) do
    coverage_finish = Coverage.start(compile_path, opts)

    fn ->
      write_lcov!(opts)
      coverage_finish.()
    end
  end

  defp write_lcov!(opts) do
    output = Keyword.get(opts, :output, "cover")
    caller_cwd = Keyword.get(opts, :cwd) || File.cwd!()
    ignored_paths = Keyword.get(opts, :ignore_paths, @ignored_paths)

    lcov =
      :cover.modules()
      |> Enum.sort()
      |> Enum.flat_map(&module_lcov(&1, ignored_paths, caller_cwd))

    File.mkdir_p!(output)
    path = "#{output}/lcov.info"
    File.write!(path, lcov, [:write])
    Mix.shell().info("\nCoverage file created at #{path}")
  end

  defp module_lcov(mod, ignored_paths, cwd) do
    path = mod.module_info(:compile)[:source] |> to_string() |> Path.relative_to(cwd)

    if Path.type(path) != :relative or Enum.any?(ignored_paths, &String.starts_with?(path, &1)) do
      []
    else
      {:ok, fun_data} = :cover.analyse(mod, :calls, :function)
      {functions_coverage, %{fnf: fnf, fnh: fnh}} = Stats.function_coverage_data(fun_data)

      {:ok, lines_data} = :cover.analyse(mod, :calls, :line)
      {lines_coverage, %{lf: lf, lh: lh}} = Stats.line_coverage_data(lines_data)

      [Formatter.format_lcov(mod, path, functions_coverage, fnf, fnh, lines_coverage, lf, lh)]
    end
  end
end
