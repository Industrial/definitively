defmodule Definitively.LogTest do
  use ExUnit.Case, async: true

  alias Definitively.Log

  setup do
    on_exit(fn ->
      System.delete_env("DEFINITIVELY_LOG_LEVEL")
      Log.configure!()
    end)

    :ok
  end

  test "configured_level defaults to info" do
    System.delete_env("DEFINITIVELY_LOG_LEVEL")
    Log.configure!()
    assert Log.configured_level() == :info
  end

  test "configured_level parses TRACE" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "TRACE")
    Log.configure!()
    assert Log.configured_level() == :trace
    assert Log.enabled?(:trace)
  end

  test "enabled? respects threshold" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "WARN")
    Log.configure!()
    refute Log.enabled?(:info)
    assert Log.enabled?(:warn)
    assert Log.enabled?(:error)
  end

  test "configured_level parses DEBUG" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "DEBUG")
    Log.configure!()
    assert Log.configured_level() == :debug
    assert Log.enabled?(:debug)
  end

  test "configured_level parses WARNING" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "WARNING")
    Log.configure!()
    assert Log.configured_level() == :warn
  end

  test "configured_level parses ERROR" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "ERROR")
    Log.configure!()
    assert Log.configured_level() == :error
    refute Log.enabled?(:info)
  end

  test "configured_level handles invalid value" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "nope")
    Log.configure!()
    assert Log.configured_level() == :info
  end

  test "log respects enabled threshold" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "ERROR")
    Log.configure!()
    assert :ok = Log.info("ignored")
    assert :ok = Log.error("emitted")
  end

  test "trace adds orchestrator_level metadata" do
    System.put_env("DEFINITIVELY_LOG_LEVEL", "TRACE")
    Log.configure!()
    assert :ok = Log.trace("trace event")
  end

  test "run_metadata builds run context keywords" do
    ctx = %Definitively.Workflow.RunContext{
      run_id: "run-1",
      workspace_root: "/tmp/ws",
      env: %{}
    }

    assert Log.run_metadata(ctx) == [run_id: "run-1", workspace: "/tmp/ws"]
  end

  test "metadata drops nil values" do
    assert Log.metadata(a: 1, b: nil) == [a: 1]
  end
end
