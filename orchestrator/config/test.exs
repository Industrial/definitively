import Config

config :orchestrator,
  llm_runner: {Orchestrator.Nodes.Llm.Stub, :run, []}
