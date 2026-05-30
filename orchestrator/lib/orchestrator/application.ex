defmodule Orchestrator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc "OTP application for the orchestrator supervision tree."

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Orchestrator.Run.Registry},
      {DynamicSupervisor, name: Orchestrator.Run.EngineSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Orchestrator.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Orchestrator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
