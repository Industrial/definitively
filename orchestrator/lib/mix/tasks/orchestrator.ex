defmodule Mix.Tasks.Orchestrator do
  @shortdoc "Runs the workflow orchestrator CLI"
  @moduledoc false

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Orchestrator.CLI.main(args)
end
