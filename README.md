# PhoenixKitStats

A [PhoenixKit](https://hex.pm/packages/phoenix_kit) plugin module for collecting and
charting time-series stats from external data sources, backed by
[Barograph](https://hex.pm/packages/barograph).

## What it does

Create a **stats group** in the admin panel (e.g. `"server1"`) for each external
source you want to monitor. Each group gets:

- its own [Barograph](https://hex.pm/packages/barograph) database — a single SQLite
  file, no separate server to run
- a dedicated Graphite plaintext TCP port a collector on that source writes
  `metric value timestamp` lines to
- an admin chart page: pick a metric, a time range, a bucket size, and an
  aggregation, and get a live SVG chart

There's no bundled collector — point any process that can open a TCP socket
(a shell one-liner, statsd/collectd relay, a custom agent) at the group's port.

```
echo "cpu.load 1.23 $(date +%s)" | nc <host> <port>
```

Labels are attached either via Graphite 1.1+ tag syntax
(`cpu.load;host=server1 1.23 1700000000`, works with no configuration) or via
an optional per-group dot-path template (e.g. `*.host.metric`).

## Security note

Graphite's plaintext protocol has **no built-in authentication**. Each group's
collector port is a bare TCP listener — restrict who can reach it at the
network layer (firewall / VPN / private interface). This module cannot enforce
access control on the wire protocol itself.

## Installation

Add to your parent app's `mix.exs`:

```elixir
{:phoenix_kit_stats, "~> 0.2"}
```

Configure where per-group Barograph files are stored (required):

```elixir
config :phoenix_kit_stats, data_dir: "/var/data/phoenix_kit_stats"
```

Optionally override the port range groups auto-allocate collector ports from
(default `9100..9200`):

```elixir
config :phoenix_kit_stats, port_range: 9100..9200
```

Then:

```bash
mix deps.get
mix phoenix_kit.update   # creates the phoenix_kit_stats_groups table
```

The module appears in the admin sidebar and Modules page automatically —
enable it from the admin panel (or `PhoenixKitStats.enable_system/0`).

## Local cross-repo development

`phoenix_kit` and `barograph` resolve from Hex by default. To build or test
this module against a **local checkout** of either — e.g. an unpublished core
change — export `<APP>_PATH` and Mix swaps the Hex pin for a `path:` +
`override: true` dep at resolve time:

```bash
PHOENIX_KIT_PATH=../phoenix_kit BAROGRAPH_PATH=../beamlab_barograph mix test
```

Unset = the published pin, so `mix hex.publish` and CI resolve exactly as before.

## Architecture

- **`PhoenixKitStats.Groups`** — context for stats group metadata (name, key,
  port, template, status) in the host app's Postgres database.
- **`PhoenixKitStats.DatabaseManager`** — a supervised `GenServer` that opens
  every active group's Barograph database + Graphite listener at boot, and on
  every create/update/pause/resume/delete thereafter. No host-app supervision
  tree changes needed — it's registered via `children/0` and picked up by
  `PhoenixKit.ModuleRegistry.static_children/0`.
- **`PhoenixKitStats.Metrics`** — thin wrapper around `Barograph.query/3`,
  `Barograph.sql/3` (for metric-name discovery), and `Barograph.Barogram.svg/2`.
- **`PhoenixKitStats.Migrations.Schema`** — versioned migration coordinator for
  `phoenix_kit_stats_groups`, picked up automatically by `mix phoenix_kit.update`
  (not part of core `phoenix_kit`'s own migration chain — no core PR needed).

## Testing

```bash
mix test.setup    # ecto.create; test_helper.exs applies schema on every boot
mix test
mix precommit      # compile + format + credo --strict + dialyzer
```

Integration tests (DB- and LiveView-backed) are tagged `:integration` and are
automatically excluded when the test Postgres database isn't available.

## License

MIT
