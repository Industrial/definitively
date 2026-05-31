defmodule Mix.Tasks.Definitively do
  @shortdoc "Runs the workflow definitively CLI"
  @moduledoc "Mix task that delegates to `Definitively.CLI`."

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    Definitively.CLI.main(args)
  end
end
