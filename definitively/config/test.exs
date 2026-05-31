import Config

config :definitively,
  llm_runner: {Definitively.Nodes.Llm.Stub, :run, []}
