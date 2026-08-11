defmodule PhoenixKitStats.MixProject do
  use Mix.Project

  @version "0.2.1"
  @source_url "https://github.com/BeamLabEU/phoenix_kit_stats"

  def project do
    [
      app: :phoenix_kit_stats,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      description:
        "Stats module for PhoenixKit — create per-source metrics groups and " <>
          "collect/chart time-series stats via Barograph.",
      package: package(),

      # Dialyzer
      dialyzer: [plt_add_apps: [:phoenix_kit]],

      # Docs
      name: "PhoenixKitStats",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :phoenix_kit]
    ]
  end

  # test/support/ is compiled only in :test so DataCase and TestRepo
  # don't leak into the published package.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer"],
      precommit: [
        "compile --force --warnings-as-errors",
        "deps.unlock --check-unused",
        # Scan for retired Hex deps. Run via `cmd` so Hex bootstraps in a fresh
        # process — the hex.* archive tasks aren't resolvable via Mix.Task.run
        # inside an alias.
        "cmd mix hex.audit",
        "quality.ci"
      ],
      # Core tables are applied by test_helper.exs via
      # PhoenixKit.Migration.ensure_current/2; this module's own table is
      # applied by calling PhoenixKitStats.Migrations.Schema.up/1 directly
      # (it isn't part of core's versioned chain) — no ecto.migrate step here.
      "test.setup": [
        "ecto.create --quiet -r PhoenixKitStats.Test.Repo"
      ],
      "test.reset": [
        "ecto.drop --quiet -r PhoenixKitStats.Test.Repo",
        "test.setup"
      ]
    ]
  end

  # phoenix_kit / barograph resolve from Hex by default. For cross-repo work
  # against a local checkout, export <APP>_PATH — e.g. PHOENIX_KIT_PATH=../phoenix_kit
  # or BAROGRAPH_PATH=../beamlab_barograph. Unset or blank => the published
  # pin, so mix hex.publish is unaffected.
  defp pk_dep(app, requirement, opts \\ []) do
    env_var = String.upcase(Atom.to_string(app)) <> "_PATH"

    case System.get_env(env_var, "") |> String.trim() do
      "" when opts == [] -> {app, requirement}
      "" -> {app, requirement, opts}
      path -> {app, [path: path, override: true] ++ opts}
    end
  end

  defp deps do
    [
      # PhoenixKit provides the Module behaviour and Settings API.
      pk_dep(:phoenix_kit, "~> 2.0"),

      # LiveView is needed for the admin pages.
      {:phoenix_live_view, "~> 1.1"},

      # Time-series storage/query/chart engine — one Barograph "database"
      # (SQLite file) per stats group.
      pk_dep(:barograph, "~> 0.2"),

      # Graphite plaintext ingest listener is core to this module's v1
      # collector path, so this is a normal (not optional) dependency here
      # even though barograph itself declares it optional.
      {:thousand_island, "~> 1.5"},

      # Optional: add ex_doc for generating documentation
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # HTML parser for Phoenix.LiveViewTest in LiveView smoke tests
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "PhoenixKitStats",
      # Tags in this repo are v-prefixed (`git tag -a v0.1.0`), matching phoenix_kit
      # core and the rest of the umbrella. Tagging a bare version number instead
      # would 404 every HexDocs source link — keep the two in step.
      source_ref: "v#{@version}"
    ]
  end
end
