ExUnit.start()

repo_root = Path.expand("../..", __DIR__)
System.put_env("DEFINITIVELY_WORKSPACE", repo_root)
System.put_env("DEFINITIVELY_LOG_LEVEL", "WARN")
System.delete_env("DEFINITIVELY_LLM_COMMAND")
Application.put_env(:definitively, :stream_output, false)

{:ok, _} = Application.ensure_all_started(:definitively)
Definitively.Log.configure!()
