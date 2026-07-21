defmodule PhoenixKitStats.Schemas.Group do
  @moduledoc """
  A stats group — one external data source (e.g. `"server1"`). Owns a
  dedicated Barograph SQLite database (see `PhoenixKitStats.DatabaseManager`)
  and a Graphite plaintext ingest port that a collector on that source
  writes metrics to.

  Tables are created by `PhoenixKitStats.Migrations.Schema`, not by this
  schema module — see `migration_module/0` on `PhoenixKitStats`.
  """

  use Ecto.Schema
  use PhoenixKit.SchemaPrefix
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:uuid, UUIDv7, autogenerate: true}
  @foreign_key_type UUIDv7

  @statuses ~w(active paused)
  @key_format ~r/^[a-z0-9_-]+$/

  schema "phoenix_kit_stats_groups" do
    field(:name, :string)
    field(:key, :string)
    field(:status, :string, default: "active")
    field(:port, :integer)
    field(:template, :string)
    field(:description, :string)
    field(:settings, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :key, :port]
  @optional_fields [:status, :template, :description, :settings]

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:key, @key_format,
      message: "must be lowercase letters, numbers, underscores, and hyphens only"
    )
    |> validate_length(:key, min: 1, max: 100)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> unique_constraint(:key, name: :phoenix_kit_stats_groups_key_index)
    |> unique_constraint(:port, name: :phoenix_kit_stats_groups_port_index)
  end
end
