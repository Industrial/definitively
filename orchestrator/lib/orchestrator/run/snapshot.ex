defmodule Orchestrator.Run.Snapshot do
  @moduledoc "Read-only view of a workflow run for CLI/MCP status queries."

  alias Orchestrator.Domain.Program
  alias Orchestrator.Workflow.RunContext

  @type t :: %__MODULE__{
          run_id: String.t() | nil,
          program_id: String.t(),
          program: Program.t() | nil,
          run_context: RunContext.t() | nil,
          current_state: atom(),
          state_type: atom() | nil,
          approval_prompt: String.t() | nil,
          history: [map()],
          done: boolean()
        }

  defstruct [
    :run_id,
    :program_id,
    :program,
    :run_context,
    :current_state,
    :state_type,
    :approval_prompt,
    :history,
    :done
  ]
end
