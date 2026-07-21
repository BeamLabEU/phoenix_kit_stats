defmodule PhoenixKitStats.Schemas.GroupTest do
  use ExUnit.Case, async: true

  alias PhoenixKitStats.Schemas.Group

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  test "valid attrs build a valid changeset" do
    changeset = Group.changeset(%Group{}, %{name: "Server 1", key: "server1", port: 9100})
    assert changeset.valid?
  end

  test "requires name, key, and port" do
    changeset = Group.changeset(%Group{}, %{})
    refute changeset.valid?
    errors = errors_on(changeset)
    assert "can't be blank" in errors.name
    assert "can't be blank" in errors.key
    assert "can't be blank" in errors.port
  end

  test "rejects keys with uppercase letters or invalid characters" do
    for bad_key <- ["Server1", "server 1", "server/1", "sérvér1"] do
      changeset = Group.changeset(%Group{}, %{name: "S", key: bad_key, port: 9100})
      refute changeset.valid?, "expected #{inspect(bad_key)} to be rejected"
    end
  end

  test "accepts lowercase letters, numbers, underscores, hyphens in key" do
    changeset = Group.changeset(%Group{}, %{name: "S", key: "server_1-a", port: 9100})
    assert changeset.valid?
  end

  test "rejects ports outside 1..65535" do
    for bad_port <- [0, -1, 70_000] do
      changeset = Group.changeset(%Group{}, %{name: "S", key: "s1", port: bad_port})
      refute changeset.valid?, "expected port #{bad_port} to be rejected"
    end
  end

  test "rejects unknown status values" do
    changeset =
      Group.changeset(%Group{}, %{name: "S", key: "s1", port: 9100, status: "bogus"})

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).status
  end

  test "defaults status to active" do
    changeset = Group.changeset(%Group{}, %{name: "S", key: "s1", port: 9100})
    assert Ecto.Changeset.get_field(changeset, :status) == "active"
  end

  test "template and description are optional" do
    changeset =
      Group.changeset(%Group{}, %{
        name: "S",
        key: "s1",
        port: 9100,
        template: "*.host.metric",
        description: "A description"
      })

    assert changeset.valid?
  end
end
