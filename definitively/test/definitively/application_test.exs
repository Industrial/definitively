defmodule Definitively.ApplicationTest do
  use ExUnit.Case, async: false

  test "start returns error when supervisor children cannot start" do
    :ok = Application.stop(:definitively)
    {:ok, reg} = Registry.start_link(keys: :unique, name: Definitively.Run.Registry)
    Process.flag(:trap_exit, true)

    try do
      assert {:error, {:shutdown, _}} = Definitively.Application.start(:normal, [])
    after
      Process.flag(:trap_exit, false)
      GenServer.stop(reg)
      {:ok, _} = Application.ensure_all_started(:definitively)
    end
  end
end
