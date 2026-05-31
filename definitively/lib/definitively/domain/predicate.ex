defmodule Definitively.Domain.Predicate do
  @moduledoc "Medium DSL predicate clauses from YAML outcome rules."

  alias Definitively.Domain.RawResult

  defp jq_matches?(".status == \"ok\"", %{"status" => "ok"}), do: true
  defp jq_matches?(".status == \"ok\"", %{status: "ok"}), do: true
  defp jq_matches?(_expr, _json), do: false

  defp jq_matches_stdout?(_expr, ""), do: false
  defp jq_matches_stdout?(_expr, _stdout), do: false

  @doc "Returns true when every predicate clause in the map matches the raw result."
  @spec matches?(map(), RawResult.t()) :: boolean()
  def matches?(predicate, raw) when is_map(predicate) do
    Enum.all?(predicate, &match_clause(&1, raw))
  end

  defp match_clause({:exit_code, expected}, %RawResult{exit_code: code}) do
    case expected do
      n when is_integer(n) -> code == n
      %{"neq" => n} -> is_integer(code) and code != n
      %{neq: n} -> is_integer(code) and code != n
      _ -> false
    end
  end

  defp match_clause({:timeout, true}, %RawResult{timed_out: true}), do: true
  defp match_clause({:timeout, _}, %RawResult{timed_out: false}), do: false

  defp match_clause({:signal, name}, %RawResult{signals: signals}) when is_binary(name) do
    signal_truthy?(Map.get(signals, name) || Map.get(signals, String.to_atom(name)))
  end

  defp match_clause({:jq, expr}, %RawResult{llm_json: json}) when is_map(json),
    do: jq_matches?(expr, json)

  defp match_clause({:jq, expr}, %RawResult{stdout: stdout}) when is_binary(stdout),
    do: jq_matches_stdout?(expr, stdout)

  defp match_clause({:jq, _expr}, _raw), do: false
  defp match_clause(_, _raw), do: false

  defp signal_truthy?(value) when value in [true, "true", 1], do: true
  defp signal_truthy?(_), do: false
end
