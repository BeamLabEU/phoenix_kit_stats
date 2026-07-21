defmodule PhoenixKitStats.Paths do
  @moduledoc """
  Centralized path helpers for the Stats module.

  All paths go through `PhoenixKit.Utils.Routes.path/1` for prefix/locale
  handling — never hardcode `"/admin/stats/..."` in a LiveView.
  """

  alias PhoenixKit.Utils.Routes

  @base "/admin/stats/groups"

  @doc "Stats groups list."
  @spec index() :: String.t()
  def index, do: Routes.path(@base)

  @doc "New group form."
  @spec new() :: String.t()
  def new, do: Routes.path("#{@base}/new")

  @doc "Edit group form."
  @spec edit(String.t()) :: String.t()
  def edit(uuid), do: Routes.path("#{@base}/#{uuid}/edit")

  @doc "Group detail / chart page."
  @spec show(String.t()) :: String.t()
  def show(uuid), do: Routes.path("#{@base}/#{uuid}")
end
