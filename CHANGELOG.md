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
