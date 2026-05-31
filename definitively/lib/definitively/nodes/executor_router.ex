defmodule Definitively.Nodes.ExecutorRouter do
  @moduledoc "Selects the executor module for a node definition."

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Nodes.{Cli, Gh, Git, Llm, Maestro}

  @doc "Returns the executor module for the node's kind."
  @spec module_for(NodeDefinition.t()) :: module()
  def module_for(%NodeDefinition{kind: :cli}), do: Cli
  def module_for(%NodeDefinition{kind: :llm}), do: Llm
  def module_for(%NodeDefinition{kind: :git}), do: Git
  def module_for(%NodeDefinition{kind: :gh}), do: Gh
  def module_for(%NodeDefinition{kind: :maestro}), do: Maestro
end
