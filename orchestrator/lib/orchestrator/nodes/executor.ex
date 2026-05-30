defmodule Orchestrator.Nodes.Executor do
  @moduledoc "Behaviour for running a workflow node and returning a `RawResult`."

  alias Orchestrator.Domain.{NodeDefinition, RawResult}
  alias Orchestrator.Workflow.RunContext

  @callback execute(NodeDefinition.t(), RunContext.t()) ::
              {:ok, RawResult.t()} | {:error, term()}
end
