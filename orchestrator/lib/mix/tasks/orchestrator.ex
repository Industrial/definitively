defmodule Mix.Tasks.Orchestrator do
  @shortdoc "Runs the workflow orchestrator CLI"
  @moduledoc "Mix task that delegates to `Orchestrator.CLI`."

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    Orchestrator.CLI.main(args)
  end
end
