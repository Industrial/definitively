defmodule Definitively.Domain.ProgramInput do
  @moduledoc "Declarative CLI input for a workflow program."

  @type input_type :: :path | :string

  @type t :: %__MODULE__{
          name: atom(),
          type: input_type(),
          required: boolean(),
          default: term() | nil,
          description: String.t() | nil
        }

  defstruct [:name, :type, :required, :default, :description]

  @doc "Returns the CLI flag for an input key (`plan_file` → `--plan-file`)."
  @spec flag(atom() | String.t()) :: String.t()
  def flag(name) when is_atom(name), do: flag(Atom.to_string(name))

  def flag(name) when is_binary(name) do
    "--" <> String.replace(name, "_", "-")
  end

  @doc "Parses a CLI flag into an input key (`--plan-file` → `plan_file`)."
  @spec key_from_flag(String.t()) :: {:ok, String.t()} | :error
  def key_from_flag("--" <> rest) do
    if rest == "" or String.starts_with?(rest, "-") do
      :error
    else
      {:ok, String.replace(rest, "-", "_")}
    end
  end

  def key_from_flag(_), do: :error
end
