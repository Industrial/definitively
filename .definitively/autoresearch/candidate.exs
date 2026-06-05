defmodule Autoresearch.Candidate do
  @moduledoc """
  Mutable experiment surface. Return `%{metric_value: float, detail: term}`.
  Lower metric_value is better. Metric = mean_loss + 0.5 * stdev_loss across targets.
  """

  def run(problem) do
    targets = Map.fetch!(problem, :targets)
    step = 0.05
    iterations = 400

    losses =
      Enum.map(targets, fn target ->
        x =
          Enum.reduce(1..iterations, 0.0, fn _, x ->
            grad = 2 * (x - target) + 0.2 * :math.sin(x) * :math.cos(x)
            x - step * grad
          end)

        :math.pow(x - target, 2) + 0.1 * :math.pow(:math.sin(x), 2)
      end)

    mean = Enum.sum(losses) / length(losses)

    stdev =
      losses
      |> Enum.map(fn l -> :math.pow(l - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(losses))
      |> :math.sqrt()

    %{
      metric_value: mean + 0.5 * stdev,
      detail: %{mean_loss: mean, stdev_loss: stdev, per_target: losses, algorithm: "fixed_lr_gd"}
    }
  end
end
