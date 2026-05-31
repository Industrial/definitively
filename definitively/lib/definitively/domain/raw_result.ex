defmodule Definitively.Domain.RawResult do
  @moduledoc "Uninterpreted output from a node executor (phase 3+)."

  @type t :: %__MODULE__{
          exit_code: non_neg_integer() | nil,
          stdout: String.t(),
          stderr: String.t(),
          duration_ms: non_neg_integer() | nil,
          timed_out: boolean(),
          signals: map(),
          llm_json: map() | nil,
          data: map() | nil
        }

  defstruct exit_code: nil,
            stdout: "",
            stderr: "",
            duration_ms: nil,
            timed_out: false,
            signals: %{},
            llm_json: nil,
            data: nil
end
