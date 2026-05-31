defmodule Definitively.Nodes.Executor do
  @moduledoc "Behaviour for running a workflow node and returning a `RawResult`."

  alias Definitively.Domain.{NodeDefinition, RawResult}
  alias Definitively.Workflow.RunContext

  @callback execute(NodeDefinition.t(), RunContext.t()) ::
              {:ok, RawResult.t()} | {:error, term()}
end
