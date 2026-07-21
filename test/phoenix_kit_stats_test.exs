defmodule PhoenixKitStatsTest do
  use ExUnit.Case

  describe "behaviour implementation" do
    test "implements PhoenixKit.Module" do
      behaviours =
        PhoenixKitStats.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert PhoenixKit.Module in behaviours
    end

    test "has @phoenix_kit_module attribute for auto-discovery" do
      attrs = PhoenixKitStats.__info__(:attributes)
      assert Keyword.get(attrs, :phoenix_kit_module) == [true]
    end
  end

  describe "required callbacks" do
    test "module_key/0 returns the expected key" do
      assert PhoenixKitStats.module_key() == "stats"
    end

    test "module_name/0 returns the expected name" do
      assert PhoenixKitStats.module_name() == "Stats"
    end

    test "enabled?/0 returns a boolean" do
      # In test env without DB started for this suite, this returns false
      # (the rescue fallback).
      assert is_boolean(PhoenixKitStats.enabled?())
    end

    test "enable_system/0 is exported" do
      assert function_exported?(PhoenixKitStats, :enable_system, 0)
    end

    test "disable_system/0 is exported" do
      assert function_exported?(PhoenixKitStats, :disable_system, 0)
    end
  end

  describe "permission_metadata/0" do
    test "returns a map with required fields" do
      meta = PhoenixKitStats.permission_metadata()
      assert %{key: key, label: label, icon: icon, description: desc} = meta
      assert is_binary(key)
      assert is_binary(label)
      assert is_binary(icon)
      assert is_binary(desc)
    end

    test "key matches module_key" do
      assert PhoenixKitStats.permission_metadata().key == PhoenixKitStats.module_key()
    end

    test "icon uses hero- prefix" do
      assert String.starts_with?(PhoenixKitStats.permission_metadata().icon, "hero-")
    end
  end

  describe "admin_tabs/0" do
    test "returns a non-empty list of Tab structs" do
      tabs = PhoenixKitStats.admin_tabs()
      assert is_list(tabs)
      assert length(tabs) == 5
    end

    test "main tab has all required fields" do
      [main | _] = PhoenixKitStats.admin_tabs()
      assert main.id == :admin_stats
      assert main.label == "Stats"
      assert is_binary(main.path)
      assert main.level == :admin
      assert main.permission == PhoenixKitStats.module_key()
      assert main.group == :admin_modules
    end

    test "all tab paths use hyphens/slashes, not underscores" do
      for tab <- PhoenixKitStats.admin_tabs() do
        refute String.contains?(tab.path, "_")
      end
    end

    test "all tabs share the same permission (module_key)" do
      for tab <- PhoenixKitStats.admin_tabs() do
        assert tab.permission == PhoenixKitStats.module_key()
      end
    end

    test "the static /new tab is listed before the dynamic :uuid tabs" do
      ids = Enum.map(PhoenixKitStats.admin_tabs(), & &1.id)
      new_index = Enum.find_index(ids, &(&1 == :admin_stats_group_new))
      edit_index = Enum.find_index(ids, &(&1 == :admin_stats_group_edit))
      show_index = Enum.find_index(ids, &(&1 == :admin_stats_group_show))

      assert new_index < edit_index
      assert new_index < show_index
    end

    test "groups tab points to GroupsLive" do
      tabs = PhoenixKitStats.admin_tabs()
      groups = Enum.find(tabs, &(&1.id == :admin_stats_groups))

      assert groups != nil
      assert groups.live_view == {PhoenixKitStats.Web.GroupsLive, :index}
    end

    test "hidden leaf tabs are not visible in the sidebar" do
      tabs = PhoenixKitStats.admin_tabs()

      for id <- [:admin_stats_group_new, :admin_stats_group_edit, :admin_stats_group_show] do
        tab = Enum.find(tabs, &(&1.id == id))
        assert tab.visible == false
      end
    end
  end

  describe "version/0" do
    test "matches mix.exs" do
      assert PhoenixKitStats.version() == Mix.Project.config()[:version]
    end
  end

  describe "css_sources/0" do
    test "returns a list with the OTP app atom" do
      assert PhoenixKitStats.css_sources() == [:phoenix_kit_stats]
    end
  end

  describe "children/0" do
    test "includes the DatabaseManager" do
      assert PhoenixKitStats.children() == [PhoenixKitStats.DatabaseManager]
    end
  end

  describe "migration_module/0" do
    test "points at the Stats migration coordinator" do
      assert PhoenixKitStats.migration_module() == PhoenixKitStats.Migrations.Schema
    end
  end

  describe "optional callbacks have defaults" do
    test "get_config/0 returns a map" do
      config = PhoenixKitStats.get_config()
      assert is_map(config)
      assert Map.has_key?(config, :enabled)
    end

    test "settings_tabs/0 returns empty list" do
      assert PhoenixKitStats.settings_tabs() == []
    end

    test "user_dashboard_tabs/0 returns empty list" do
      assert PhoenixKitStats.user_dashboard_tabs() == []
    end

    test "route_module/0 returns nil" do
      assert PhoenixKitStats.route_module() == nil
    end

    test "required_integrations/0 returns empty list" do
      assert PhoenixKitStats.required_integrations() == []
    end
  end

  describe "Paths" do
    alias PhoenixKitStats.Paths

    test "index/0 returns a path string pointing to the Stats groups list" do
      path = Paths.index()
      assert is_binary(path)
      assert String.contains?(path, "stats/groups")
    end

    test "new/0 returns the new-group subpath" do
      assert String.ends_with?(Paths.new(), "stats/groups/new")
    end

    test "edit/1 and show/1 include the given uuid" do
      uuid = "00000000-0000-0000-0000-000000000000"
      assert String.ends_with?(Paths.edit(uuid), "stats/groups/#{uuid}/edit")
      assert String.ends_with?(Paths.show(uuid), "stats/groups/#{uuid}")
    end

    test "all Paths helpers return prefix-aware strings" do
      assert String.starts_with?(Paths.new(), Paths.index())
    end
  end
end
