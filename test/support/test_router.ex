defmodule PhoenixKitStats.Test.Router do
  @moduledoc """
  Minimal Router used by the LiveView test suite. Routes match the URLs
  produced by `PhoenixKitStats.Paths` so `live/2` calls in tests work
  with exactly the same URLs the LiveViews push themselves to.

  `PhoenixKit.Utils.Routes.path/1` defaults to no URL prefix when the
  `phoenix_kit_settings` table is unavailable, and admin paths always
  get the default locale ("en") prefix — so our base becomes
  `/en/admin/stats/groups`.
  """

  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {PhoenixKitStats.Test.Layouts, :root})
    plug(:protect_from_forgery)
  end

  scope "/en/admin/stats/groups", PhoenixKitStats.Web do
    pipe_through(:browser)

    live_session :stats_test,
      layout: {PhoenixKitStats.Test.Layouts, :app},
      on_mount: {PhoenixKitStats.Test.Hooks, :assign_scope} do
      live("/", GroupsLive, :index)
      live("/new", GroupFormLive, :new)
      live("/:uuid/edit", GroupFormLive, :edit)
      live("/:uuid", GroupShowLive, :show)
    end
  end
end
