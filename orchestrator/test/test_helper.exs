ExUnit.start()

repo_root = Path.expand("../..", __DIR__)
System.put_env("ORCHESTRATOR_WORKSPACE", repo_root)
System.put_env("ORCHESTRATOR_LOG_LEVEL", "WARN")
Application.put_env(:orchestrator, :stream_output, false)

{:ok, _} = Application.ensure_all_started(:orchestrator)
Orchestrator.Log.configure!()
