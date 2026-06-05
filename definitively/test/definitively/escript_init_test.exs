defmodule Definitively.EscriptInitTest do
  use ExUnit.Case, async: false

  @moduletag :escript

  @project_dir Path.expand("../..", __DIR__)
  @escript Path.join(@project_dir, "definitively")

  test "prod escript init scaffolds .definitively from embedded templates" do
    assert {_, 0} =
             System.cmd("mix", ["escript.build"],
               cd: @project_dir,
               env: [{"MIX_ENV", "prod"}]
             )

    workspace =
      Path.join(System.tmp_dir!(), "orch_escript_" <> Integer.to_string(System.unique_integer()))

    File.mkdir_p!(workspace)

    on_exit(fn -> File.rm_rf(workspace) end)

    {output, 0} =
      System.cmd(@escript, ["init"],
        cd: workspace,
        env: [{"DEFINITIVELY_WORKSPACE", workspace}],
        stderr_to_stdout: true
      )

    program = Path.join([workspace, ".definitively", "programs", "example.yml"])

    assert output =~ "definitively workspace initialized"
    assert File.regular?(program)
    assert File.read!(program) =~ "id: example"
  end
end
