defmodule Definitively.TemplatesTest do
  use ExUnit.Case, async: true

  alias Definitively.Templates

  test "manifest includes scaffold files" do
    manifest = Templates.manifest()

    assert Templates.count() == 16
    assert Map.has_key?(manifest, "programs/example.yml")
    assert Map.has_key?(manifest, "agents/cursor.yml")
    assert Map.has_key?(manifest, ".gitignore")
    assert manifest["programs/example.yml"] =~ "id: example"
  end
end
