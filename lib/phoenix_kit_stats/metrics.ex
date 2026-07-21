defmodule PhoenixKitStats.Metrics do
  @moduledoc """
  Thin wrapper around Barograph for querying and charting a stats
  group's time-series data.

  Group *metadata* CRUD (name, key, port, status) lives in
  `PhoenixKitStats.Groups`; this module only reads/renders metric data
  from a group's already-open Barograph database (see
  `PhoenixKitStats.DatabaseManager`).
  """

  alias PhoenixKitStats.DatabaseManager
  alias PhoenixKitStats.Schemas.Group

  @doc """
  Lists distinct metric names recorded in a group's database.

  No dedicated Barograph API exists for this — it's the intended use of
  Barograph's "raw SQL, never second-class" guarantee against its
  internal `bg_series` table.
  """
  @spec list_metric_names(Group.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_metric_names(%Group{} = group) do
    with {:ok, db} <- DatabaseManager.get_db(group.uuid),
         {:ok, rows} <-
           Barograph.sql(db, "SELECT DISTINCT metric FROM bg_series ORDER BY metric") do
      {:ok, Enum.map(rows, & &1["metric"])}
    end
  end

  @doc "Lists series (metric + labels) for a group, optionally filtered to one metric."
  @spec list_series(Group.t(), String.t() | nil) :: {:ok, [map()]} | {:error, term()}
  def list_series(%Group{} = group, metric \\ nil) do
    with {:ok, db} <- DatabaseManager.get_db(group.uuid) do
      {sql, params} =
        case metric do
          nil -> {"SELECT metric, labels FROM bg_series ORDER BY metric", []}
          m -> {"SELECT metric, labels FROM bg_series WHERE metric = ?1 ORDER BY metric", [m]}
        end

      with {:ok, rows} <- Barograph.sql(db, sql, params) do
        {:ok,
         Enum.map(rows, fn row ->
           %{metric: row["metric"], labels: JSON.decode!(row["labels"])}
         end)}
      end
    end
  end

  @doc "Runs a bucketed/raw time-series query for one metric. See `Barograph.query/3` for `opts`."
  @spec query(Group.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def query(%Group{} = group, metric, opts \\ []) do
    with {:ok, db} <- DatabaseManager.get_db(group.uuid) do
      Barograph.query(db, metric, opts)
    end
  end

  @doc """
  Runs `query/3` and renders the result as a Barograph SVG line chart.

  `opts` accepts both query options (`:labels`, `:from`, `:to`,
  `:bucket`, `:agg`) and chart options (`:width`, `:height`, `:style`) —
  the chart-only keys are split out before querying.
  """
  @spec chart_svg(Group.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def chart_svg(%Group{} = group, metric, opts \\ []) do
    {chart_opts, query_opts} = Keyword.split(opts, [:width, :height, :style])

    with {:ok, points} <- query(group, metric, query_opts) do
      {:ok, Barograph.Barogram.svg(points, chart_opts)}
    end
  end
end
