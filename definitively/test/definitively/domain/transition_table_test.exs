defmodule Definitively.Domain.TransitionTableTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.TransitionTable
  alias Definitively.Spec.Loader

  @fixture Path.expand("../../fixtures/dev_quality_loop.yml", __DIR__)

  setup do
    {:ok, program} = Loader.load(@fixture)
    table = TransitionTable.build(program)
    {:ok, program: program, table: table}
  end

  test "lint success goes to commit", %{table: table} do
    assert {:ok, :commit} = TransitionTable.next(table, :lint, :success)
  end

  test "lint failure goes to fix", %{table: table} do
    assert {:ok, :fix} = TransitionTable.next(table, :lint, :failure)
  end

  test "fix retry loops on fix", %{table: table} do
    assert {:ok, :fix} = TransitionTable.next(table, :fix, :retry)
  end

  test "idle start goes to lint", %{table: table} do
    assert {:ok, :lint} = TransitionTable.next(table, :idle, :start)
  end

  test "unknown transition returns error", %{table: table} do
    assert {:error, :no_transition} = TransitionTable.next(table, :done, :success)
  end
end
