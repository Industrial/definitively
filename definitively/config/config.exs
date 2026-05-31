import Config

config :definitively, llm_runner: nil

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :definitively_level,
    :run_id,
    :program_id,
    :workspace,
    :path,
    :state,
    :from_state,
    :to_state,
    :label,
    :node_id,
    :kind,
    :outcome,
    :status,
    :exit_code,
    :duration_ms,
    :timed_out,
    :command,
    :error,
    :log_file
  ]

import_config "#{config_env()}.exs"
