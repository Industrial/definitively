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
test "returns error for invalid yaml" do
    dir = System.tmp_dir!()
    agents = Path.join(dir, ".definitively/agents")
    File.mkdir_p!(agents)
    path = Path.join(agents, "broken.yml")
    File.write!(path, "[unclosed")

    on_exit(fn -> File.rm_rf!(Path.join(dir, ".definitively")) end)

    assert {:error, %{reason: :invalid_agent_yaml}} = Loader.load(:broken, dir)
  end

  test "rejects profile missing agent section" do
    dir = System.tmp_dir!()
    agents = Path.join(dir, ".definitively/agents")
    File.mkdir_p!(agents)
    path = Path.join(agents, "noagent.yml")
    File.write!(path, "name: only\n")

    on_exit(fn -> File.rm_rf!(Path.join(dir, ".definitively")) end)

    assert {:error, %{reason: :invalid_agent_profile}} = Loader.load(:noagent, dir)
  end

  test "defaults profile id from filename when agent.id omitted" do
    dir = System.tmp_dir!()
    agents = Path.join(dir, ".definitively/agents")
    File.mkdir_p!(agents)
    path = Path.join(agents, "implicit.yml")

    File.write!(path, """
    agent:
      executable: echo
      argv: []
      prompt:
        mode: stdin
      output:
        format: json
        extract: whole_stdout
    """)

    on_exit(fn -> File.rm_rf!(Path.join(dir, ".definitively")) end)

    assert {:ok, %AgentProfile{id: :implicit}} = Loader.load(:implicit, dir)
  end

  test "treats non-list argv as empty and coerces invalid output fields" do
    dir = System.tmp_dir!()
    agents = Path.join(dir, ".definitively/agents")
    File.mkdir_p!(agents)
    path = Path.join(agents, "coerce.yml")

    File.write!(path, """
    agent:
      id: coerce
      executable: echo
      argv: not-a-list
      prompt:
        mode: bogus
      output:
        format: bogus
        extract: bogus
    """)

    on_exit(fn -> File.rm_rf!(Path.join(dir, ".definitively")) end)

    assert {:ok, profile} = Loader.load(:coerce, dir)
    assert profile.argv == []
    assert profile.prompt.mode == :argv_after_delimiter
    assert profile.output.format == :json
    assert profile.output.extract == :whole_stdout
  end
end
