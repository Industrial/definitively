defmodule Definitively.CLI.InputParserTest do
  use ExUnit.Case, async: true

  alias Definitively.CLI.InputParser
  alias Definitively.Domain.{Program, ProgramInput}
  alias Definitively.Spec.Loader

  @fixture Path.expand("../../fixtures/with_inputs.yml", __DIR__)

  setup do
    {:ok, program} = Loader.load(@fixture)
    {:ok, program: program, workspace: "/tmp/ws"}
  end

  test "parses spaced and equals flags", %{program: program, workspace: ws} do
    assert {:ok, inputs} =
             InputParser.parse(
               ["--plan-file", "plans/x.md", "--agent=claude"],
               program,
               ws
             )

    assert inputs["plan_file"] == Path.expand("plans/x.md", ws)
    assert inputs["agent"] == "claude"
  end

  test "applies defaults for optional inputs", %{program: program, workspace: ws} do
    assert {:ok, inputs} = InputParser.parse(["--plan-file", "p.md"], program, ws)
    assert inputs["agent"] == "cursor"
  end

  test "rejects unknown flags", %{program: program, workspace: ws} do
    assert {:error, {:unknown_flag, "--nope", _}} =
             InputParser.parse(["--nope", "x"], program, ws)
  end

  test "rejects missing required inputs", %{program: program, workspace: ws} do
    assert {:error, {:missing_required, ["--plan-file"]}} =
             InputParser.parse([], program, ws)
  end

  test "help lines include declared inputs", %{program: program} do
    lines = InputParser.help_lines(program)
    assert Enum.any?(lines, &String.contains?(&1, "--plan-file"))
    assert Enum.any?(lines, &String.contains?(&1, "--agent"))
  end

  test "empty inputs for program without declarations" do
    program = %Program{id: "x", version: 1, initial: :idle, states: %{}, nodes: %{}}
    assert {:ok, %{}} = InputParser.parse([], program, "/tmp")
  end
end
