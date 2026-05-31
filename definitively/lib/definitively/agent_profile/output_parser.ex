defmodule Definitively.AgentProfile.OutputParser do
  @moduledoc "Parses LLM subprocess stdout using agent profile output config."

  alias Definitively.Domain.AgentProfile

  @type parse_result :: {:ok, map()} | :error

  @doc "Parses stdout into a JSON envelope map."
  @spec parse(String.t(), AgentProfile.output_config() | AgentProfile.t()) :: parse_result()
  def parse(output, %AgentProfile{output: config}), do: parse(output, config)

  def parse(output, config) when is_map(config) do
    case config.format do
      :stream_json -> parse_stream_json(output, config)
      :json -> parse_json(output, config)
      :text -> {:ok, %{"status" => config.success_status, "raw" => output}}
    end
  end

  @doc "Returns true when parsed output indicates a successful completion."
  @spec stream_complete?(String.t(), AgentProfile.output_config() | AgentProfile.t()) :: boolean()
  def stream_complete?(output, config) do
    case parse(output, config) do
      {:ok, %{"status" => status}} -> status == success_status(config)
      _ -> ok_envelope_in_stream?(output)
    end
  end

  defp success_status(%{success_status: status}), do: status
  defp success_status(%AgentProfile{output: %{success_status: status}}), do: status

  defp parse_json(output, _config) do
    case Jason.decode(output) do
      {:ok, %{} = map} -> {:ok, map}
      _ -> :error
    end
  end

  defp parse_stream_json(output, config) do
    case config.extract do
      :whole_stdout -> parse_json(output, config)
      :last_json_line -> parse_last_json_line(output, config)
    end
  end

  defp parse_last_json_line(output, config) do
    line_result =
      output
      |> String.split("\n", trim: true)
      |> Enum.reverse()
      |> Enum.find_value(&decode_line(&1, config))

    case line_result do
      {:ok, _} = ok ->
        ok

      _ ->
        if ok_envelope_in_stream?(output) do
          {:ok, %{"status" => config.success_status, "signals" => %{"fix_complete" => true}}}
        else
          :error
        end
    end
  end

  defp decode_line(line, config) do
    case Jason.decode(line) do
      {:ok, %{"status" => _} = map} ->
        {:ok, map}

      {:ok, map} when is_map(map) ->
        unwrap_envelope(map, config)

      _ ->
        nil
    end
  end

  defp unwrap_envelope(map, %{envelope_path: nil}), do: {:ok, map}

  defp unwrap_envelope(map, %{envelope_path: path}) when is_binary(path) do
    case get_in(map, envelope_keys(path)) do
      payload when is_map(payload) ->
        {:ok, payload}

      payload when is_binary(payload) ->
        case Jason.decode(payload) do
          {:ok, %{"status" => _} = inner} -> {:ok, inner}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp envelope_keys(path), do: String.split(path, ".")

  defp ok_envelope_in_stream?(output) do
    String.contains?(output, ~S("status":"ok")) and
      String.contains?(output, ~S("fix_complete":true))
  end
end
