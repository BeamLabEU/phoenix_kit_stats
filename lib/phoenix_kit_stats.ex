defmodule PhoenixKitStats do
  @moduledoc """
  PhoenixKit plugin module for collecting and charting time-series stats.

  An admin creates a **stats group** (e.g. `"server1"`) representing one
  external data source. Each group gets its own [Barograph](https://hex.pm/packages/barograph)
  database (a single SQLite file) and a dedicated Graphite plaintext TCP
  port. Whatever collector process runs on that source writes
  `metric value timestamp` lines to the port; the admin picks a metric on
  the group's page and gets a live SVG chart.

  ## How it works

  1. `use PhoenixKit.Module` marks this module as a plugin (persists a
     `@phoenix_kit_module` attribute in the `.beam` file).
  2. PhoenixKit scans `.beam` files at startup and discovers this module
     automatically — no config line needed.
  3. `children/0` starts `PhoenixKitStats.DatabaseManager`, which opens
     every active group's Barograph database + Graphite listener.
  4. `migration_module/0` points at `PhoenixKitStats.Migrations.Schema`,
     which `mix phoenix_kit.update` uses to create/upgrade
     `phoenix_kit_stats_groups` in the host app's database — no core
     `phoenix_kit` PR required.

  ## Installation

  Add to your parent app's `mix.exs`:

      {:phoenix_kit_stats, "~> 0.1.0"}

  Then configure where per-group Barograph files are stored (required):

      config :phoenix_kit_stats, data_dir: "/var/data/phoenix_kit_stats"

  Optionally override the port range groups auto-allocate collector ports
  from (default `9100..9200`):

      config :phoenix_kit_stats, port_range: 9100..9200

  Run `mix deps.get`, then `mix phoenix_kit.update` to create the
  `phoenix_kit_stats_groups` table. The module appears in the admin
  sidebar and Modules page automatically.

  ## Security note

  Graphite's plaintext protocol has no built-in authentication — each
  group's collector port is a bare TCP listener. Restrict who can reach
  those ports at the network layer (firewall / VPN / private interface);
  this module cannot enforce access control on the wire protocol itself.

  ## Navigation paths

  All navigation goes through `PhoenixKitStats.Paths`, which wraps
  `PhoenixKit.Utils.Routes.path/1` for prefix/locale handling.
  """

  use PhoenixKit.Module

  alias PhoenixKit.Dashboard.Tab
  alias PhoenixKit.Settings

  # ===========================================================================
  # Required callbacks
  # ===========================================================================

  @impl PhoenixKit.Module
  @doc "Unique key for this module. Used in settings, permissions, and PubSub events."
  def module_key, do: "stats"

  @impl PhoenixKit.Module
  @doc "Display name shown in the admin UI."
  def module_name, do: "Stats"

  @impl PhoenixKit.Module
  @doc """
  Whether the module is currently enabled.

  Reads from the DB-backed settings table. Defensive against DB not
  being available yet (startup ordering, missing table, sandbox
  artifacts in tests) — always falls back to `false`.
  """
  def enabled? do
    Settings.get_boolean_setting("stats_enabled", false)
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end

  @impl PhoenixKit.Module
  @doc "Enables the module by persisting a boolean setting."
  def enable_system do
    Settings.update_boolean_setting_with_module("stats_enabled", true, module_key())
  end

  @impl PhoenixKit.Module
  @doc "Disables the module. Same pattern as `enable_system/0`."
  def disable_system do
    Settings.update_boolean_setting_with_module("stats_enabled", false, module_key())
  end

  # ===========================================================================
  # Optional callbacks
  # ===========================================================================

  @impl PhoenixKit.Module
  @doc "Version string. Shown on the admin Modules page."
  def version, do: "0.1.0"

  @impl PhoenixKit.Module
  @doc "Permission metadata for the roles/permissions matrix."
  def permission_metadata do
    %{
      key: module_key(),
      label: "Stats",
      icon: "hero-chart-bar",
      description: "Per-source metrics groups collecting time-series stats via Barograph"
    }
  end

  @impl PhoenixKit.Module
  @doc """
  Admin sidebar tabs: a parent tab plus a visible "Groups" list and
  hidden leaf tabs for the new/edit/show pages. Static `/new` is ordered
  before the `:uuid` wildcard tabs so PhoenixKit's route generation
  (which registers routes in list order) doesn't let the wildcard shadow it.
  """
  def admin_tabs do
    [
      %Tab{
        id: :admin_stats,
        label: "Stats",
        icon: "hero-chart-bar",
        path: "stats",
        priority: 645,
        level: :admin,
        permission: module_key(),
        match: :prefix,
        group: :admin_modules,
        redirect_to_first_subtab: true,
        subtab_display: :when_active,
        highlight_with_subtabs: false
      },
      %Tab{
        id: :admin_stats_groups,
        label: "Groups",
        icon: "hero-server-stack",
        path: "stats/groups",
        priority: 646,
        level: :admin,
        permission: module_key(),
        parent: :admin_stats,
        live_view: {PhoenixKitStats.Web.GroupsLive, :index}
      },
      %Tab{
        id: :admin_stats_group_new,
        label: "New Group",
        path: "stats/groups/new",
        priority: 647,
        level: :admin,
        permission: module_key(),
        parent: :admin_stats_groups,
        visible: false,
        live_view: {PhoenixKitStats.Web.GroupFormLive, :new}
      },
      %Tab{
        id: :admin_stats_group_edit,
        label: "Edit Group",
        path: "stats/groups/:uuid/edit",
        priority: 648,
        level: :admin,
        permission: module_key(),
        parent: :admin_stats_groups,
        visible: false,
        live_view: {PhoenixKitStats.Web.GroupFormLive, :edit}
      },
      %Tab{
        id: :admin_stats_group_show,
        label: "Group",
        path: "stats/groups/:uuid",
        priority: 649,
        level: :admin,
        permission: module_key(),
        parent: :admin_stats_groups,
        visible: false,
        live_view: {PhoenixKitStats.Web.GroupShowLive, :show}
      }
    ]
  end

  @impl PhoenixKit.Module
  @doc "OTP apps whose templates Tailwind should scan for CSS classes."
  def css_sources, do: [:phoenix_kit_stats]

  @impl PhoenixKit.Module
  @doc """
  Starts `PhoenixKitStats.DatabaseManager` under the host's
  `PhoenixKit.Supervisor` (via `PhoenixKit.ModuleRegistry.static_children/0`).
  No host-app supervision tree changes needed.
  """
  def children, do: [PhoenixKitStats.DatabaseManager]

  @impl PhoenixKit.Module
  @doc """
  Versioned migration coordinator for `phoenix_kit_stats_groups`. Picked
  up automatically by `mix phoenix_kit.update` — this module's table is
  not part of core `phoenix_kit`'s own migration chain.
  """
  def migration_module, do: PhoenixKitStats.Migrations.Schema
end
