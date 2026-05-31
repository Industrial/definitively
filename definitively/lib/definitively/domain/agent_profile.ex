defmodule Definitively.Domain.AgentProfile do
  @moduledoc "YAML agent profile for LLM node subprocess invocation."

  @type prompt_mode :: :argv_after_delimiter | :flag | :stdin
  @type output_format :: :stream_json | :json | :text
  @type extract_mode :: :last_json_line | :whole_stdout

  @type prompt_config :: %{
          mode: prompt_mode(),
          flag: String.t() | nil
        }

  @type output_config :: %{
          format: output_format(),
          extract: extract_mode(),
          envelope_path: String.t() | nil,
          success_status: String.t()
        }

  @type t :: %__MODULE__{
          id: atom(),
          executable: String.t() | nil,
          executable_env: String.t() | nil,
          argv: [String.t()],
          prompt: prompt_config(),
          output: output_config()
        }

  defstruct [
    :id,
    :executable,
    :executable_env,
    argv: [],
    prompt: %{mode: :argv_after_delimiter, flag: nil},
    output: %{
      format: :json,
      extract: :whole_stdout,
      envelope_path: nil,
      success_status: "ok"
    }
  ]

  @doc "Default output config for legacy command/stub LLM paths."
  @spec legacy_output() :: output_config()
  def legacy_output do
    %{
      format: :stream_json,
      extract: :last_json_line,
      envelope_path: "result",
      success_status: "ok"
    }
  end
end
