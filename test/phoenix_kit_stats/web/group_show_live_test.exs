defmodule PhoenixKitStats.Web.GroupShowLiveTest do
  use PhoenixKitStats.LiveCase

  alias PhoenixKitStats.Groups

  setup do
    Application.put_env(:phoenix_kit_stats, :data_dir, System.tmp_dir!())
    :ok
  end

  defp unique_port, do: 22_000 + System.unique_integer([:positive, :monotonic])

  test "renders the collector endpoint and an empty-metrics state", %{conn: conn} do
    port = unique_port()
    {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: port})

    conn = put_test_scope(conn, fake_scope())
    {:ok, _view, html} = live(conn, "/en/admin/stats/groups/#{group.uuid}")

    assert html =~ "Server 1"
    assert html =~ to_string(port)
    assert html =~ "No metrics recorded yet"
  end

  test "redirects with a flash for an unknown group", %{conn: conn} do
    conn = put_test_scope(conn, fake_scope())

    assert {:error, {:live_redirect, %{to: to}}} =
             live(conn, "/en/admin/stats/groups/#{Ecto.UUID.generate()}")

    assert to =~ "/stats/groups"
  end
end
