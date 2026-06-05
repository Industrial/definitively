defmodule Definitively.Version do
  @moduledoc false

  @spec version() :: String.t()
  def version do
    Application.spec(:definitively, :vsn)
    |> to_string()
  end

  @spec string() :: String.t()
  def string, do: "definitively #{version()}"
end
