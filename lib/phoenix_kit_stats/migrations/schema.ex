defmodule PhoenixKitStats.Migrations.Schema do
  @moduledoc """
  Versioned migration for the Stats module.

  Creates the `phoenix_kit_stats_groups` table. All statements use
  IF NOT EXISTS guards — safe to run multiple times.

  Implements the versioned-migration protocol expected by PhoenixKit Core
  (`mix phoenix_kit.update`): `current_version/0` and
  `migrated_version_runtime/1`. Reference implementation —
  `PhoenixKit.Modules.Legal.Migrations.ConsentLogs` in `phoenix_kit_legal`.
  """

  use Ecto.Migration

  @current_version 1

  @doc "Target schema version of the Stats module."
  def current_version, do: @current_version

  @doc """
  Currently applied schema version, read from the database.

  Returns `0` when the `phoenix_kit_stats_groups` table does not yet
  exist, and `#{@current_version}` once it has been created. `opts` is a
  keyword list with an optional `:prefix`.
  """
  def migrated_version_runtime(opts \\ []) do
    prefix = normalize_prefix(opts)

    table =
      if prefix == "public",
        do: "public.phoenix_kit_stats_groups",
        else: "#{prefix}.phoenix_kit_stats_groups"

    case PhoenixKit.RepoHelper.repo().query("SELECT to_regclass($1)", [table]) do
      {:ok, %{rows: [[nil]]}} -> 0
      {:ok, %{rows: [[_oid]]}} -> @current_version
      _ -> 0
    end
  rescue
    _ -> 0
  end

  @doc """
  Applies the Stats module migration.

  Accepts a keyword list (the form Core passes) or a map, for backward
  compatibility.
  """
  def up(opts \\ []) do
    prefix = normalize_prefix(opts)
    prefix_str = prefix_str(prefix)

    execute("""
    CREATE TABLE IF NOT EXISTS #{prefix_str}phoenix_kit_stats_groups (
      uuid UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
      name VARCHAR(255) NOT NULL,
      key VARCHAR(100) NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'active',
      port INTEGER NOT NULL,
      template VARCHAR(255),
      description TEXT,
      settings JSONB NOT NULL DEFAULT '{}',
      inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS phoenix_kit_stats_groups_key_index
    ON #{prefix_str}phoenix_kit_stats_groups (key)
    """)

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS phoenix_kit_stats_groups_port_index
    ON #{prefix_str}phoenix_kit_stats_groups (port)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS phoenix_kit_stats_groups_status_index
    ON #{prefix_str}phoenix_kit_stats_groups (status)
    """)
  end

  @doc """
  Rolls back the Stats module migration.

  Accepts a keyword list (the form Core passes) or a map, for backward
  compatibility.
  """
  def down(opts \\ []) do
    prefix_str = prefix_str(normalize_prefix(opts))
    execute("DROP TABLE IF EXISTS #{prefix_str}phoenix_kit_stats_groups CASCADE")
  end

  # Core passes a keyword list (`prefix: "public", version: 1`);
  # the legacy mechanism used a map (`%{prefix: "public"}`). Support both.
  defp normalize_prefix(opts) when is_list(opts), do: opts[:prefix] || "public"
  defp normalize_prefix(%{prefix: prefix}), do: prefix || "public"
  defp normalize_prefix(_), do: "public"

  defp prefix_str(prefix) when prefix in [nil, "public"], do: ""
  defp prefix_str(prefix), do: "#{prefix}."
end
