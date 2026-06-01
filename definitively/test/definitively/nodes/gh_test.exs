defmodule Definitively.Nodes.GhTest do
  use ExUnit.Case, async: false

  alias Definitively.Domain.NodeDefinition
  alias Definitively.Domain.RawResult
  alias Definitively.Nodes.Gh
  alias Definitively.Workflow.RunContext

  setup do
    prev = Application.get_env(:definitively, :gh_runner)
    prev_path = System.get_env("PATH")

    on_exit(fn ->
      restore_gh_runner(prev)

      if prev_path do
        System.put_env("PATH", prev_path)
      else
        System.delete_env("PATH")
      end
    end)

    :ok
  end

  test "uses injectable gh_runner" do
    Application.put_env(:definitively, :gh_runner, {__MODULE__, :fake_run, []})

    node = %NodeDefinition{
      id: :pr,
      kind: :gh,
      action: :pr_create,
      options: %{"title" => "Hi"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.data["url"] =~ "pull"
  end

  test "rejects non-gh nodes" do
    node = %NodeDefinition{id: :x, kind: :git, action: :status, outcome: %{}}
    ctx = %RunContext{run_id: "t", workspace_root: ".", env: %{}}
    assert {:error, {:unsupported_kind, :git}} = Gh.execute(node, ctx)
  end

  test "run_gh enriches pr_create stdout" do
    tmp = workspace_with_fake_gh(pr_create_script())

    node = %NodeDefinition{
      id: :pr,
      kind: :gh,
      action: :pr_create,
      options: %{"title" => "Hi"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.data["url"] =~ "pull/7"
    assert raw.data["number"] == 7
  end

  test "run_gh resolve_then_watch merges list and watch stdout" do
    tmp = workspace_with_fake_gh(resolve_then_watch_script())

    node = %NodeDefinition{
      id: :watch,
      kind: :gh,
      action: :run_watch,
      options: %{"workflow" => "ci.yml"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.exit_code == 0
    assert raw.stdout =~ "999"
    assert raw.stdout =~ "completed"
  end

  test "run_gh resolve_then_watch enriches when run list fails" do
    tmp = workspace_with_fake_gh(invalid_list_script())

    node = %NodeDefinition{
      id: :watch,
      kind: :gh,
      action: :run_watch,
      options: %{"workflow" => "ci.yml"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.exit_code == 1
    assert raw.stdout =~ "not-json"
  end

  test "returns error when run id cannot be resolved" do
    tmp = workspace_with_fake_gh(unparseable_list_script())

    node = %NodeDefinition{
      id: :watch,
      kind: :gh,
      action: :run_watch,
      options: %{"workflow" => "ci.yml"},
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:error, :no_run_found} = Gh.execute(node, ctx)
  end

  test "resolve_then_watch returns timed_out when list hangs" do
    tmp = workspace_with_fake_gh(slow_list_script())

    node = %NodeDefinition{
      id: :watch,
      kind: :gh,
      action: :run_watch,
      options: %{"workflow" => "ci.yml"},
      timeout_ms: 50,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.timed_out
  end

  test "run_gh returns timed_out raw without enrichment" do
    tmp = workspace_with_fake_gh(slow_script())

    node = %NodeDefinition{
      id: :slow,
      kind: :gh,
      action: :pr_create,
      options: %{"title" => "Hi"},
      timeout_ms: 50,
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: tmp, env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.timed_out
    assert is_nil(raw.data)
  end

  test "expands relative cwd under workspace root" do
    tmp = Path.join(System.tmp_dir!(), "def-gh-cwd-#{System.unique_integer()}")
    sub = Path.join(tmp, "repo")
    File.mkdir_p!(sub)

    bin = Path.join(tmp, "bin")
    File.mkdir_p!(bin)
    gh = Path.join(bin, "gh")

    File.write!(
      gh,
      "#!/bin/sh\nif [ \"$(pwd)\" = \"#{sub}\" ]; then echo https://github.com/o/r/pull/3; else exit 2; fi\n"
    )

    File.chmod!(gh, 0o755)
    prepend_path(bin)
    Application.delete_env(:definitively, :gh_runner)

    node = %NodeDefinition{
      id: :pr,
      kind: :gh,
      action: :pr_create,
      options: %{"title" => "Hi"},
      cwd: ".",
      outcome: %{}
    }

    ctx = %RunContext{run_id: "t", workspace_root: sub, env: %{}}
    assert {:ok, raw} = Gh.execute(node, ctx)
    assert raw.exit_code == 0
  end

  def fake_run(_node, _ctx, _argv, _cwd, _timeout) do
    {:ok,
     %RawResult{
       exit_code: 0,
       stdout: "https://github.com/o/r/pull/42\n",
       data: %{"url" => "https://github.com/o/r/pull/42", "number" => 42}
     }}
  end

  defp workspace_with_fake_gh(script) do
    tmp = Path.join(System.tmp_dir!(), "def-gh-#{System.unique_integer()}")
    bin = Path.join(tmp, "bin")
    File.mkdir_p!(bin)
    gh = Path.join(bin, "gh")
    File.write!(gh, script)
    File.chmod!(gh, 0o755)
    prepend_path(bin)
    Application.delete_env(:definitively, :gh_runner)
    tmp
  end

  defp prepend_path(bin) do
    prev = System.get_env("PATH") || ""
    System.put_env("PATH", bin <> ":" <> prev)
  end

  defp pr_create_script do
    "#!/bin/sh\ncase \"$1\" in pr) echo https://github.com/o/r/pull/7 ;; esac\n"
  end

  defp resolve_then_watch_script do
    """
    #!/bin/sh
    case "$1" in
      run)
        if [ "$2" = "list" ]; then
          echo '[{"databaseId":999}]'
        elif [ "$2" = "watch" ]; then
          echo completed
        fi
        ;;
    esac
    """
  end

  defp invalid_list_script do
    "#!/bin/sh\ncase \"$1 $2\" in \"run list\") echo not-json; exit 1 ;; esac\n"
  end

  defp unparseable_list_script do
    "#!/bin/sh\ncase \"$1 $2\" in \"run list\") echo not-json ;; esac\n"
  end

  defp slow_list_script do
    "#!/bin/sh\ncase \"$1 $2\" in \"run list\") sleep 60 ;; esac\n"
  end

  defp slow_script do
    "#!/bin/sh\nsleep 60\n"
  end

  defp restore_gh_runner(nil), do: Application.delete_env(:definitively, :gh_runner)
  defp restore_gh_runner(val), do: Application.put_env(:definitively, :gh_runner, val)
end
