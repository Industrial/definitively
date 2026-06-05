defmodule Definitively.VersionTest do
  use ExUnit.Case, async: true

  test "version matches mix project" do
    assert Definitively.Version.version() == "0.5.0"
    assert Definitively.Version.string() == "definitively 0.5.0"
  end
end
