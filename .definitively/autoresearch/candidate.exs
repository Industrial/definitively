defmodule Autoresearch.Candidate do
  @moduledoc """
  Mutable experiment surface — the autoresearch agent may edit this file only.

  Implement `run/1` returning `%{metric_value: float, detail: term}`.
  Lower `metric_value` is better.
  """

  def run(problem) do
    target = problem.target_x
    step = 0.05
    iterations = 500

    x =
      Enum.reduce(1..iterations, 0.0, fn _, x ->
        grad = 2 * (x - target) + 0.2 * :math.sin(x) * :math.cos(x)
        x - step * grad
      end)

    metric = :math.pow(x - target, 2) + 0.1 * :math.pow(:math.sin(x), 2)

    %{metric_value: metric, detail: %{x: x, iterations: iterations, step: step}}
  end
end
