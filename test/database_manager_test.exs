defmodule PhoenixKitStats.DatabaseManagerTest do
  use ExUnit.Case, async: false

  alias PhoenixKitStats.DatabaseManager
  alias PhoenixKitStats.Metrics
  alias PhoenixKitStats.Schemas.Group

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "pks_dbmanager_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    Application.put_env(:phoenix_kit_stats, :data_dir, tmp_dir)

    on_exit(fn -> File.rm_rf(tmp_dir) end)

    :ok
  end

  defp build_group do
    %Group{
      uuid: Ecto.UUID.generate(),
      name: "Test",
      key: "test-#{System.unique_integer([:positive])}",
      port: 20_000 + System.unique_integer([:positive, :monotonic]),
      status: "active",
      template: nil
    }
  end

  test "open_group/1 opens a real Barograph db reachable via get_db/1" do
    group = build_group()

    assert :ok = DatabaseManager.open_group(group)
    assert {:ok, _db} = DatabaseManager.get_db(group.uuid)

    DatabaseManager.close_group(group.uuid)
  end

  test "get_db/1 returns :not_open for an unknown group" do
    assert {:error, :not_open} = DatabaseManager.get_db(Ecto.UUID.generate())
  end

  test "close_group/1 frees the db and the port" do
    group = build_group()
    :ok = DatabaseManager.open_group(group)

    :ok = DatabaseManager.close_group(group.uuid)
    assert {:error, :not_open} = DatabaseManager.get_db(group.uuid)

    # Reopening on the same port succeeds now that it's free.
    assert :ok = DatabaseManager.open_group(group)
    DatabaseManager.close_group(group.uuid)
  end

  test "write via a Graphite line + query via Metrics round-trips a sample" do
    group = build_group()
    :ok = DatabaseManager.open_group(group)

    ts = System.system_time(:second)
    line = "demo.metric 42 #{ts}\n"

    {:ok, socket} = :gen_tcp.connect(~c"localhost", group.port, [:binary, active: false])
    :ok = :gen_tcp.send(socket, line)
    :gen_tcp.close(socket)

    # Ingest is async — the writer batches on batch_size or a ~100ms
    # timeout, whichever comes first (spec'd Barograph behavior), and the
    # series (bg_series) can become visible slightly before the sample
    # itself (bg_samples) is flushed. Poll on the actual query result
    # rather than just series existence to avoid that race.
    assert wait_until(fn ->
             match?({:ok, [%{value: 42.0}]}, Metrics.query(group, "demo.metric"))
           end)

    {:ok, svg} = Metrics.chart_svg(group, "demo.metric")
    assert svg =~ "<svg"

    DatabaseManager.close_group(group.uuid)
  end

  defp wait_until(fun, attempts \\ 20)
  defp wait_until(_fun, 0), do: false

  defp wait_until(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(50)
      wait_until(fun, attempts - 1)
    end
  end
end
