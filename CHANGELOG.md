## Unreleased

### Changed

- **Core pin widened to accept core 3.x** (ceiling `< 4.0.0`; the floor is unchanged).

## 0.2.2 - 2026-10-24

### Fixed

- Field labels on the group form and the group page's Metric/Range pickers
  rendered at 60% opacity because they used daisyUI 4 classes
  (`form-control`, `label-text`, `label-text-alt`, `select-bordered`) that do
  not exist in daisyUI 5. They now use the v5 equivalents (`fieldset`,
  `fieldset-legend`, `fieldset-label`; v5 selects are bordered by default).
- HexDocs "source" links pointed at a `v`-prefixed tag that this repo never
  creates; they now point at the release tag.

### Changed

- Dependency refresh: `phoenix_kit` 2.64.1 and its transitive set.

## 0.2.1 - 2026-08-11

### Changed

- Dependency updates: `phoenix_kit` 2.2.0 and the transitive set it pulls
  (`phoenix` 1.8.10, `hackney` 4.7.3). No source changes in this package.

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
