defmodule Definitively.Application do
  @moduledoc "OTP application for the definitively supervision tree."

  use Application

  alias Definitively.Log

  @impl true
  def start(_type, _args) do
    Log.configure!()
    Log.info("definitively application starting")

    children = [
      {Registry, keys: :unique, name: Definitively.Run.Registry},
      {DynamicSupervisor, name: Definitively.Run.EngineSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Definitively.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Definitively.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} = ok ->
        Log.info("definitively application started", supervisor: inspect(pid))
        ok

      {:error, reason} = err ->
        Log.error("definitively application failed to start", error: inspect(reason))
        err
    end
  end
end
