defmodule Definitively.StartLinkTest do
  use ExUnit.Case, async: false

  alias Definitively.Workflow.Engine

  test "start_link registers a named worker" do
    if pid = Process.whereis(Engine), do: :gen_statem.stop(pid)

    assert {:ok, pid} = Engine.start_link()
    assert Process.whereis(Engine) == pid

    :ok = :gen_statem.stop(pid)
  end
end
