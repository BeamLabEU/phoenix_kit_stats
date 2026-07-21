# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

PhoenixKitStats — a PhoenixKit plugin module for collecting and charting
time-series stats from external data sources. An admin creates a **stats
group** (e.g. `"server1"`); each group gets its own
[Barograph](https://hex.pm/packages/barograph) database (a single SQLite file)
and a dedicated Graphite plaintext TCP port. Whatever collector process runs
on that source writes `metric value timestamp` lines to the port; the admin
picks a metric on the group's page and gets a live SVG chart.

## Common Commands

```bash
mix deps.get                # Install dependencies
mix test.setup              # createdb (schema applied by test_helper.exs)
mix test                    # Run all tests
mix test test/groups_test.exs
mix format                  # Format code
mix credo --strict          # Lint / code quality
mix dialyzer                # Static type checking
mix precommit               # compile + format + credo --strict + dialyzer
```

## Dependencies

This is a **library** (not a standalone Phoenix app) — no `config/` endpoint
or router of its own.

- `phoenix_kit` (`~> 1.7.189`) — Module behaviour, Settings, RepoHelper, Activity, Dashboard tabs
- `phoenix_live_view` — admin LiveViews
- `barograph` (`~> 0.2`) — time-series storage/query/SVG chart engine
- `thousand_island` (`~> 1.5`) — Graphite TCP listener transport (required here, not optional — the Graphite ingest path is core to v1)

## Local cross-repo development

`phoenix_kit` and `barograph` resolve from Hex by default. Export
`<APP>_PATH` to swap either for a local `path:` + `override: true` dep at
resolve time:

```bash
PHOENIX_KIT_PATH=../phoenix_kit BAROGRAPH_PATH=../beamlab_barograph mix test
```

Unset = the published pin, so `mix hex.publish` and CI are unaffected.
Implemented via `pk_dep/3` in `mix.exs` — never hand-edit a path dep in.

## Architecture

### Data model

`phoenix_kit_stats_groups` (Postgres, host app's DB) stores group *metadata*
only: `name`, `key` (slug — also the `.bg` filename), `status`
(`"active"`/`"paused"`), `port` (the group's Graphite TCP port), `template`
(optional dot-path label-extraction template), `description`, `settings`.
Created via `PhoenixKitStats.Migrations.Schema`, a self-contained versioned
migration coordinator (`migration_module/0` on `PhoenixKitStats`) picked up by
`mix phoenix_kit.update` — **not** part of core `phoenix_kit`'s own migration
chain, no core PR needed. Reference: `PhoenixKit.Modules.Legal.Migrations.ConsentLogs`
in `phoenix_kit_legal`.

Actual metric *data* lives entirely in each group's own Barograph SQLite file
(`<data_dir>/<key>.bg`) — never in Postgres.

### Process layer

`PhoenixKitStats.DatabaseManager` is a `GenServer` supervised via
`children/0` (picked up by `PhoenixKit.ModuleRegistry.static_children/0` —
no host-app supervision tree changes needed). It owns every active group's
open Barograph database + Graphite listener:

- boots by opening every `status: "active"` group (`handle_continue/2` defers
  the Repo-dependent scan until after supervisor init; a single group's
  port-bind failure is logged and skipped, never crashes app boot)
- `open_group/1` / `close_group/1` are called at runtime by
  `PhoenixKitStats.Groups` on create/update/pause/resume/delete — no app
  restart is ever required
- `get_db/1` hands the open Barograph handle to `PhoenixKitStats.Metrics` for
  querying/charting

### Contexts

- `PhoenixKitStats.Groups` — group metadata CRUD + activity logging (mirrors
  `phoenix_kit_locations`'s `Locations` context shape: private `repo/0`,
  `opts \\ []` threaded to `PhoenixKit.Activity.log/1`, rescue-wrapped
  logging that never crashes the primary operation)
- `PhoenixKitStats.Metrics` — thin wrapper around `Barograph.query/3`,
  `Barograph.sql/3` (metric-name discovery — Barograph has no dedicated API
  for this, it's the intended use of its "raw SQL, never second-class"
  guarantee against `bg_series`), and `Barograph.Barogram.svg/2`
- `PhoenixKitStats.Errors` — atom→gettext dispatcher, same shape as
  `phoenix_kit_locations/lib/phoenix_kit_locations/errors.ex`

### Known trade-off: no ingest authentication

Graphite's plaintext protocol has no built-in auth. Each group's collector
port is a bare TCP listener — access control is the host's responsibility
(firewall/VPN/bind address), not something this module enforces. This is
inherent to the chosen protocol, not an oversight — see the "Security note"
in README.md.

## Critical Conventions

- **Module key**: `"stats"`, consistent across all callbacks
- **Tab IDs**: prefixed `:admin_stats`
- **URL paths**: `stats/groups`, `stats/groups/new`, `stats/groups/:uuid/edit`,
  `stats/groups/:uuid` — static `/new` listed before the `:uuid` wildcard
  tabs in `admin_tabs/0` since PhoenixKit generates routes in list order
- **Navigation**: always via `PhoenixKitStats.Paths`, never relative paths
- **`enabled?/0`**: must rescue errors and return `false` as fallback
- **LiveViews**: use `use PhoenixKitWeb, :live_view` (imports `<.input>`,
  `<.select>`, `<.textarea>`, `<.simple_form>`, `<.icon>`, etc.) — but it does
  **not** auto-import the bare `gettext/1` macro; call
  `Gettext.gettext(PhoenixKitWeb.Gettext, "...")` explicitly (matches
  `phoenix_kit_hello_world`'s demonstrated convention — verified by grepping
  its LiveViews, which never use a bare `gettext(...)` call despite using the
  same `use PhoenixKitWeb, :live_view` macro)
- **Ecto schemas**: UUIDv7 PK named `uuid`, `use PhoenixKit.SchemaPrefix`
  right after `use Ecto.Schema`, `timestamps(type: :utc_datetime)`, table
  prefixed `phoenix_kit_stats_`

## Testing

Module owns its own test database (`phoenix_kit_stats_test`). Core tables
come from `PhoenixKit.Migration.ensure_current/2`; this module's own
`phoenix_kit_stats_groups` table is applied via
`Ecto.Migrator.run(Repo, [{1, PhoenixKitStats.Test.SchemaMigration}], :up, all: true)`
in `test/test_helper.exs` — `PhoenixKitStats.Migrations.Schema.up/1` uses
`Ecto.Migration`'s `execute/1`, which only works inside an active
`Ecto.Migration.Runner`, so it can't be called as a bare function; the
`SchemaMigration` wrapper (`test/support/schema_migration.ex`) is exactly what
`mix phoenix_kit.update` would generate as a real migration file in a host app.

`PhoenixKitStats.DatabaseManager` is started unconditionally in
`test_helper.exs` (even when the test DB is unavailable) since
`PhoenixKitStats.Groups.create_group/2` calls into it unconditionally; its
boot-time group scan gracefully rescues DB/sandbox errors rather than
crashing.

Tests that create groups should draw ports from a wide, test-file-local range
(`base + System.unique_integer([:positive, :monotonic])`) — `create_group/2`
opens a real Barograph database + TCP listener as a side effect, so reusing a
literal port across tests in the same file causes (harmless but noisy)
port-bind failures once the first test's listener stays open past its DB
transaction rollback.

```bash
mix test                                   # All tests (excludes :integration if no DB)
mix test test/groups_test.exs
mix test test/phoenix_kit_stats/web        # LiveView smoke tests only
```
