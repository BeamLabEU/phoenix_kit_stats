import Config

# Test database configuration
# Integration tests need a real PostgreSQL database. Create it with:
#   mix test.setup       # createdb (schema applied by test_helper.exs)
config :phoenix_kit_stats, ecto_repos: [PhoenixKitStats.Test.Repo]

config :phoenix_kit_stats, PhoenixKitStats.Test.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "phoenix_kit_stats_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support/postgres"

# Wire repo for PhoenixKit.RepoHelper — without this, all DB calls crash.
config :phoenix_kit, repo: PhoenixKitStats.Test.Repo

# Test Endpoint for LiveView tests. `phoenix_kit_stats` has no endpoint of
# its own in production — the host app provides one — so this endpoint
# only exists for `Phoenix.LiveViewTest`.
config :phoenix_kit_stats, PhoenixKitStats.Test.Endpoint,
  secret_key_base: String.duplicate("t", 64),
  live_view: [signing_salt: "stats-test-salt"],
  server: false,
  url: [host: "localhost"],
  render_errors: [formats: [html: PhoenixKitStats.Test.Layouts]]

# Barograph `.bg` files for tests live under a throwaway tmp dir, and use a
# high port range unlikely to collide with real services in CI/sandboxes.
config :phoenix_kit_stats,
  data_dir: Path.join(System.tmp_dir!(), "phoenix_kit_stats_test"),
  port_range: 19_100..19_200

config :phoenix, :json_library, Jason

config :logger, level: :warning
