defmodule PhoenixKitStats.GroupsTest do
  use PhoenixKitStats.DataCase, async: false

  alias PhoenixKitStats.Groups

  setup do
    Application.put_env(:phoenix_kit_stats, :data_dir, System.tmp_dir!())
    :ok
  end

  # Real Barograph databases + Graphite TCP listeners get opened as a side
  # effect of create/update/pause/resume (via DatabaseManager) — draw ports
  # from a wide, test-only range so parallel-in-file tests never collide.
  # The `port_range`/`next_available_port` tests below use their own
  # narrow, deliberately-exhaustible range instead.
  defp unique_port, do: 20_000 + System.unique_integer([:positive, :monotonic])

  describe "list_groups/1 and get_group/1" do
    test "returns created groups and filters by status" do
      {:ok, active} = Groups.create_group(%{name: "Active", key: "active-1", port: unique_port()})
      {:ok, paused} = Groups.create_group(%{name: "Paused", key: "paused-1", port: unique_port()})
      {:ok, _paused} = Groups.pause_group(paused)

      assert Enum.map(Groups.list_groups(), & &1.uuid) |> Enum.sort() ==
               Enum.sort([active.uuid, paused.uuid])

      assert [only_active] = Groups.list_groups(status: "active")
      assert only_active.uuid == active.uuid

      assert Groups.get_group(active.uuid).name == "Active"
      assert Groups.get_group(Ecto.UUID.generate()) == nil
    end

    test "get_group_by_key/1 finds by slug" do
      {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: unique_port()})
      assert Groups.get_group_by_key("server1").uuid == group.uuid
      assert Groups.get_group_by_key("nope") == nil
    end
  end

  describe "create_group/2" do
    test "creates with valid attrs and logs activity" do
      {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: unique_port()})

      assert group.name == "Server 1"
      assert group.status == "active"

      assert_activity_logged("stats_group.created", resource_uuid: group.uuid)
    end

    test "returns a changeset error for duplicate key" do
      {:ok, _} = Groups.create_group(%{name: "A", key: "dupe", port: unique_port()})
      {:error, changeset} = Groups.create_group(%{name: "B", key: "dupe", port: unique_port()})

      assert "has already been taken" in errors_on(changeset).key
    end

    test "returns a changeset error for duplicate port" do
      port = unique_port()
      {:ok, _} = Groups.create_group(%{name: "A", key: "a1", port: port})
      {:error, changeset} = Groups.create_group(%{name: "B", key: "b1", port: port})

      assert "has already been taken" in errors_on(changeset).port
    end
  end

  describe "update_group/3, pause_group/2, resume_group/2" do
    test "updates fields" do
      {:ok, group} = Groups.create_group(%{name: "Old", key: "u1", port: unique_port()})
      {:ok, updated} = Groups.update_group(group, %{name: "New"})

      assert updated.name == "New"
      assert_activity_logged("stats_group.updated", resource_uuid: group.uuid)
    end

    test "pause then resume round-trips status" do
      {:ok, group} = Groups.create_group(%{name: "G", key: "p1", port: unique_port()})

      {:ok, paused} = Groups.pause_group(group)
      assert paused.status == "paused"
      assert_activity_logged("stats_group.paused", resource_uuid: group.uuid)

      {:ok, resumed} = Groups.resume_group(paused)
      assert resumed.status == "active"
      assert_activity_logged("stats_group.resumed", resource_uuid: group.uuid)
    end
  end

  describe "delete_group/2" do
    test "removes the row and logs activity" do
      {:ok, group} = Groups.create_group(%{name: "G", key: "d1", port: unique_port()})
      {:ok, _deleted} = Groups.delete_group(group)

      assert Groups.get_group(group.uuid) == nil
      assert_activity_logged("stats_group.deleted", resource_uuid: group.uuid)
    end
  end

  describe "next_available_port/0 and port_range/0" do
    setup do
      previous = Application.get_env(:phoenix_kit_stats, :port_range)
      Application.put_env(:phoenix_kit_stats, :port_range, 19_500..19_501)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:phoenix_kit_stats, :port_range, previous),
          else: Application.delete_env(:phoenix_kit_stats, :port_range)
      end)

      :ok
    end

    test "returns the lowest free port in the configured range" do
      assert Groups.next_available_port() == 19_500

      {:ok, _} = Groups.create_group(%{name: "G", key: "port1", port: 19_500})
      assert Groups.next_available_port() == 19_501
    end

    test "returns nil once the range is exhausted" do
      {:ok, _} = Groups.create_group(%{name: "G", key: "only1", port: 19_500})
      {:ok, _} = Groups.create_group(%{name: "G2", key: "only2", port: 19_501})

      assert Groups.next_available_port() == nil
    end
  end
end
