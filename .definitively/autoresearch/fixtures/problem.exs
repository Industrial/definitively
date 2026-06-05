# Immutable benchmark — statistical robustness across multiple targets.
%{
  targets: [10.0, 42.0, -7.5, 100.0],
  budget_seconds: 30,
  description: "minimize mean_loss + 0.5 * stdev_loss across targets (lower is better)"
}
