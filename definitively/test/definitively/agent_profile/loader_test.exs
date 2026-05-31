defmodule Definitively.AgentProfile.LoaderTest do
  use ExUnit.Case, async: true

  alias Definitively.AgentProfile.Loader
  alias Definitively.Domain.AgentProfile

  @fixtures Path.expand("../../fixtures", __DIR__)

  test "loads stub agent profile from workspace" do
    assert {:ok, %AgentProfile{id: :stub, executable: "sh"}} =
             Loader.load(:stub, @fixtures)
  end

  test "returns error when profile missing" do
    assert {:error, %{reason: :agent_profile_not_found}} = Loader.load(:missing, @fixtures)
  end

  test "rejects id mismatch with filename" do
    dir = System.tmp_dir!()
    agents = Path.join(dir, ".definitively/agents")
    File.mkdir_p!(agents)
    path = Path.join(agents, "wrong.yml")
    File.write!(path, "agent:\n  id: other\n  executable: echo\n")

    on_exit(fn -> File.rm_rf!(Path.join(dir, ".definitively")) end)

    assert {:error, %{reason: :agent_id_mismatch}} = Loader.load(:wrong, dir)
  end

  test "rejects profile missing executable" do
    dir = System.tmp_dir!()
    agents = Path.join(dir, ".definitively/agents")
    File.mkdir_p!(agents)
    path = Path.join(agents, "bad.yml")

    File.write!(path, """
    agent:
      id: bad
      argv: []
      prompt:
        mode: stdin
      output:
        format: json
        extract: whole_stdout
    """)

    on_exit(fn -> File.rm_rf!(Path.join(dir, ".definitively")) end)

    assert {:error, %{reason: :missing_executable}} = Loader.load(:bad, dir)
  end
end
