defmodule Definitively.Workflow.RunContext do
  @moduledoc "Ephemeral context passed to node executors for a single run."

  @type t :: %__MODULE__{
          run_id: String.t(),
          workspace_root: String.t(),
          inputs: map(),
          env: map(),
          attempt: non_neg_integer()
        }

  defstruct [:run_id, :workspace_root, :env, attempt: 0, inputs: %{}]
end
