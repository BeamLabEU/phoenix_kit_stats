## 0.2.0 - 2026-08-10

### Changed

- **⚠️ Requires `phoenix_kit ~> 2.0`.** The core pin moved to `~> 2.0`, so this
  release no longer resolves against core 1.7.

  Core 2.0.0 squashes the migration chain into a single `V135` baseline and makes
  V135 the chain's floor: `mix ecto.migrate` now *refuses* on a database below it
  rather than migrating. Check `mix phoenix_kit.status` **before** upgrading. A
  host below V135 must install `phoenix_kit 1.7.236` — the migration bridge, the
  last release carrying the full pre-squash chain — migrate until the reported
  version is at least V135, and only then move to 2.0.

  This package does not call migration internals, so the change is the pin
  itself.

## 0.1.0 - 2026-07-21

### Added
- Initial release: stats groups (`PhoenixKitStats.Groups`), per-group Barograph
  database + Graphite plaintext ingest listener management
  (`PhoenixKitStats.DatabaseManager`), metric querying/charting
  (`PhoenixKitStats.Metrics`), and admin pages to create/pause/resume/delete
  groups and chart their metrics (`Web.GroupsLive`, `Web.GroupFormLive`,
  `Web.GroupShowLive`).
- Versioned migration (`PhoenixKitStats.Migrations.Schema`) for
  `phoenix_kit_stats_groups`, applied via `mix phoenix_kit.update`.
