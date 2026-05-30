defmodule Orchestrator.Application do
  @moduledoc "OTP application for the orchestrator supervision tree."

  use Application

  alias Orchestrator.Log

  @impl true
  def start(_type, _args) do
    Log.configure!()
    Log.info("orchestrator application starting")

    children = [
      {Registry, keys: :unique, name: Orchestrator.Run.Registry},
      {DynamicSupervisor, name: Orchestrator.Run.EngineSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Orchestrator.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Orchestrator.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} = ok ->
        Log.info("orchestrator application started", supervisor: inspect(pid))
        ok

      {:error, reason} = err ->
        Log.error("orchestrator application failed to start", error: inspect(reason))
        err
    end
  end
end
