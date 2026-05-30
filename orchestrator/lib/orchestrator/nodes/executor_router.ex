defmodule Orchestrator.Nodes.ExecutorRouter do
  @moduledoc "Selects the executor module for a node definition."

  alias Orchestrator.Domain.NodeDefinition
  alias Orchestrator.Nodes.{Cli, Llm}

  @doc "Returns the executor module for the node's kind."
  @spec module_for(NodeDefinition.t()) :: module()
  def module_for(%NodeDefinition{kind: :cli}), do: Cli
  def module_for(%NodeDefinition{kind: :llm}), do: Llm
end
