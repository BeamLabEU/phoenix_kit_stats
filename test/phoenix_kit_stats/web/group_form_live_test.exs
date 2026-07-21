defmodule PhoenixKitStats.Web.GroupFormLiveTest do
  use PhoenixKitStats.LiveCase

  alias PhoenixKitStats.Groups

  setup do
    Application.put_env(:phoenix_kit_stats, :data_dir, System.tmp_dir!())
    :ok
  end

  defp unique_port, do: 21_500 + System.unique_integer([:positive, :monotonic])

  test "new group form validates and creates a group", %{conn: conn} do
    conn = put_test_scope(conn, fake_scope())
    {:ok, view, _html} = live(conn, "/en/admin/stats/groups/new")

    html = view |> form("form", group: %{name: ""}) |> render_change()
    assert html =~ "can&#39;t be blank"

    port = unique_port()

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> form("form", group: %{name: "Server 1", key: "server1", port: port})
      |> render_submit()

    assert to =~ "/stats/groups/"
    assert Groups.get_group_by_key("server1").port == port
  end

  test "edit form loads existing group values and updates them", %{conn: conn} do
    {:ok, group} = Groups.create_group(%{name: "Old Name", key: "old-key", port: unique_port()})

    conn = put_test_scope(conn, fake_scope())
    {:ok, view, html} = live(conn, "/en/admin/stats/groups/#{group.uuid}/edit")

    assert html =~ "Old Name"

    {:error, {:live_redirect, _}} =
      view
      |> form("form", group: %{name: "New Name"})
      |> render_submit()

    assert Groups.get_group(group.uuid).name == "New Name"
  end

  test "redirects with a flash when editing an unknown group", %{conn: conn} do
    conn = put_test_scope(conn, fake_scope())

    assert {:error, {:live_redirect, %{to: to}}} =
             live(conn, "/en/admin/stats/groups/#{Ecto.UUID.generate()}/edit")

    assert to =~ "/stats/groups"
  end
end
