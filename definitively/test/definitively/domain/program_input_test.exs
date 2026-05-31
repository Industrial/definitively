defmodule Definitively.Domain.ProgramInputTest do
  use ExUnit.Case, async: true

  alias Definitively.Domain.ProgramInput

  test "flag and key conversion" do
    assert ProgramInput.flag(:plan_file) == "--plan-file"
    assert {:ok, "plan_file"} = ProgramInput.key_from_flag("--plan-file")
    assert :error = ProgramInput.key_from_flag("plan-file")
  end
end
