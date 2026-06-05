#!/usr/bin/env elixir
# Immutable evaluation harness — do not modify during autoresearch runs.

format_float = fn value ->
  :erlang.float_to_binary(value * 1.0, decimals: 6)
end

sandbox = Path.dirname(__ENV__.file)
problem_path = Path.join(sandbox, "fixtures/problem.exs")
candidate_path = Path.join(sandbox, "candidate.exs")

{problem, _} = Code.eval_file(problem_path)
budget_ms = Map.fetch!(problem, :budget_seconds) * 1000

start_ms = System.monotonic_time(:millisecond)
mem_before = :erlang.memory(:total)

try do
  {_, _} = Code.eval_file(candidate_path)
  result = Autoresearch.Candidate.run(problem)
  elapsed_ms = System.monotonic_time(:millisecond) - start_ms
  mem_after = :erlang.memory(:total)
  peak_mem_mb = max(mem_before, mem_after) / 1024 / 1024

  if elapsed_ms > budget_ms do
    IO.puts(:stderr, "budget exceeded: #{elapsed_ms}ms > #{budget_ms}ms")
    System.halt(1)
  end

  metric = Map.fetch!(result, :metric_value)

  IO.puts("---")
  IO.puts("metric_value:     #{format_float.(metric)}")
  IO.puts("runtime_seconds:  #{format_float.(elapsed_ms / 1000)}")
  IO.puts("peak_mem_mb:      #{format_float.(peak_mem_mb)}")
  IO.puts("---")
rescue
  exception ->
    IO.puts(:stderr, Exception.format(:error, exception, __STACKTRACE__))
    System.halt(1)
end
