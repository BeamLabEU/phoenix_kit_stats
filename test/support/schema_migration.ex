defmodule PhoenixKitStats.Test.SchemaMigration do
  @moduledoc """
  Thin `Ecto.Migration` wrapper that runs `PhoenixKitStats.Migrations.Schema`
  against the test repo.

  `PhoenixKitStats.Migrations.Schema.up/1` uses `Ecto.Migration`'s
  `execute/1`, which only works inside an active
  `Ecto.Migration.Runner` — it can't be called as a bare function. In
  production, `mix phoenix_kit.update` generates exactly this kind of
  wrapper as a real migration file under the host app's
  `priv/repo/migrations/`. `test_helper.exs` runs this one in-memory via
  `Ecto.Migrator.run/4` to get the same effect without a host app.
  """

  use Ecto.Migration

  alias PhoenixKitStats.Migrations.Schema

  def up, do: Schema.up(prefix: "public")
  def down, do: Schema.down(prefix: "public")
end
