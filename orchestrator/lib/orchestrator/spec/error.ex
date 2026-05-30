defmodule Orchestrator.Spec.Error do
  @moduledoc "Structured error from spec load or validation."

  @type t :: %__MODULE__{
          reason: atom(),
          message: String.t(),
          path: String.t() | nil
        }

  defstruct [:reason, :message, :path]

  @spec new(atom(), String.t(), String.t() | nil) :: t()
  def new(reason, message, path \\ nil) do
    %__MODULE__{reason: reason, message: message, path: path}
  end
end
