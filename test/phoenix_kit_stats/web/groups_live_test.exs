defmodule PhoenixKitStats.Web.GroupsLiveTest do
  use PhoenixKitStats.LiveCase

  alias PhoenixKitStats.Groups

  setup do
    Application.put_env(:phoenix_kit_stats, :data_dir, System.tmp_dir!())
    :ok
  end

  defp unique_port, do: 21_000 + System.unique_integer([:positive, :monotonic])

  test "renders the empty state with no groups", %{conn: conn} do
    conn = put_test_scope(conn, fake_scope())
    {:ok, _view, html} = live(conn, "/en/admin/stats/groups")

    assert html =~ "Stats Groups"
    assert html =~ "No stats groups yet"
  end

  test "lists an existing group", %{conn: conn} do
    {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: unique_port()})

    conn = put_test_scope(conn, fake_scope())
    {:ok, _view, html} = live(conn, "/en/admin/stats/groups")

    assert html =~ group.name
    assert html =~ group.key
  end

  test "pause and resume update the row in place", %{conn: conn} do
    {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: unique_port()})

    conn = put_test_scope(conn, fake_scope())
    {:ok, view, _html} = live(conn, "/en/admin/stats/groups")

    html =
      view |> element("button[phx-click=pause][phx-value-uuid='#{group.uuid}']") |> render_click()

    assert html =~ "paused"
    assert Groups.get_group(group.uuid).status == "paused"

    html =
      view
      |> element("button[phx-click=resume][phx-value-uuid='#{group.uuid}']")
      |> render_click()

    assert html =~ "active"
    assert Groups.get_group(group.uuid).status == "active"
  end

  test "delete removes the row", %{conn: conn} do
    {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: unique_port()})

    conn = put_test_scope(conn, fake_scope())
    {:ok, view, _html} = live(conn, "/en/admin/stats/groups")

    view |> element("button[phx-click=delete][phx-value-uuid='#{group.uuid}']") |> render_click()

    assert Groups.get_group(group.uuid) == nil
  end
end
