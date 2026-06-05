defmodule Definitively.Templates do
  @moduledoc false

  @root Path.expand("../../priv/templates/definitively", __DIR__)

  @manifest (
    root = @root

    for abs <-
          root
          |> Path.join("**/*")
          |> Path.wildcard(match_dot: true)
          |> Enum.filter(&File.regular?/1)
          |> Enum.sort() do
      {Path.relative_to(abs, root), File.read!(abs)}
    end
    |> Map.new()
  )

  @spec manifest() :: %{String.t() => String.t()}
  def manifest, do: @manifest

  @spec count() :: non_neg_integer()
  def count, do: map_size(@manifest)
end
