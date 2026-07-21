defmodule PhoenixKitStats.Web.GroupShowLive do
  @moduledoc """
  Chart page for a stats group: shows the collector endpoint + an
  example command, lets the admin pick a metric + time range + bucket +
  aggregation, and renders the resulting Barograph SVG chart.
  """

  use PhoenixKitWeb, :live_view

  require Logger

  import Phoenix.HTML, only: [raw: 1]

  alias PhoenixKitStats.Errors
  alias PhoenixKitStats.Groups
  alias PhoenixKitStats.Metrics
  alias PhoenixKitStats.Paths

  @bucket_options [
    {"1 minute", "1m"},
    {"5 minutes", "5m"},
    {"1 hour", "1h"},
    {"1 day", "1d"}
  ]
  @agg_options [
    {"Average", "avg"},
    {"Sum", "sum"},
    {"Min", "min"},
    {"Max", "max"},
    {"Count", "count"}
  ]
  @range_options [
    {"Last hour", 3600},
    {"Last 24 hours", 86_400},
    {"Last 7 days", 604_800},
    {"Last 30 days", 2_592_000}
  ]

  @impl true
  def mount(%{"uuid" => uuid}, _session, socket) do
    case Groups.get_group(uuid) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, Errors.message(:group_not_found))
         |> push_navigate(to: Paths.index())}

      group ->
        {:ok,
         socket
         |> assign(
           page_title: group.name,
           group: group,
           bucket_options: @bucket_options,
           agg_options: @agg_options,
           range_options: @range_options,
           metric: nil,
           bucket: "5m",
           agg: "avg",
           range_seconds: 86_400,
           chart_svg: nil,
           metric_names: []
         )
         |> load_metric_names()}
    end
  end

  defp load_metric_names(socket) do
    case Metrics.list_metric_names(socket.assigns.group) do
      {:ok, names} ->
        metric = socket.assigns.metric || List.first(names)
        socket |> assign(metric_names: names, metric: metric) |> load_chart()

      {:error, reason} ->
        Logger.debug("[GroupShowLive] list_metric_names failed: #{inspect(reason)}")
        assign(socket, metric_names: [], metric: nil, chart_svg: nil)
    end
  end

  defp load_chart(%{assigns: %{metric: nil}} = socket), do: assign(socket, chart_svg: nil)

  defp load_chart(socket) do
    %{group: group, metric: metric, bucket: bucket, agg: agg, range_seconds: range} =
      socket.assigns

    opts = [
      bucket: bucket_tuple(bucket),
      agg: String.to_existing_atom(agg),
      from: DateTime.add(DateTime.utc_now(), -range, :second),
      to: DateTime.utc_now()
    ]

    case Metrics.chart_svg(group, metric, opts) do
      {:ok, svg} ->
        assign(socket, chart_svg: svg)

      {:error, reason} ->
        Logger.debug("[GroupShowLive] chart_svg failed: #{inspect(reason)}")

        socket
        |> assign(chart_svg: nil)
        |> put_flash(:error, Gettext.gettext(PhoenixKitWeb.Gettext, "Could not load chart data."))
    end
  end

  defp bucket_tuple("1m"), do: {1, :minute}
  defp bucket_tuple("5m"), do: {5, :minute}
  defp bucket_tuple("1h"), do: {1, :hour}
  defp bucket_tuple("1d"), do: {1, :day}

  @impl true
  def handle_event("update_chart", params, socket) do
    socket =
      socket
      |> assign(
        metric: Map.get(params, "metric", socket.assigns.metric),
        bucket: Map.get(params, "bucket", socket.assigns.bucket),
        agg: Map.get(params, "agg", socket.assigns.agg),
        range_seconds:
          params
          |> Map.get("range", to_string(socket.assigns.range_seconds))
          |> String.to_integer()
      )
      |> load_chart()

    {:noreply, socket}
  end

  def handle_event("refresh_metrics", _params, socket) do
    {:noreply, load_metric_names(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col w-full px-4 py-8 gap-6">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold">{@group.name}</h2>
          <p class="text-sm text-base-content/60 mt-1">
            <code class="text-xs">{@group.key}</code>
            <span class={[
              "badge badge-sm ml-2",
              @group.status == "active" && "badge-success",
              @group.status == "paused" && "badge-ghost"
            ]}>
              {@group.status}
            </span>
          </p>
        </div>
        <.link navigate={Paths.edit(@group.uuid)} class="btn btn-ghost btn-sm">
          {Gettext.gettext(PhoenixKitWeb.Gettext, "Edit")}
        </.link>
      </div>

      <div class="card bg-base-100 shadow-lg">
        <div class="card-body gap-2">
          <h3 class="font-semibold">{Gettext.gettext(PhoenixKitWeb.Gettext, "Collector endpoint")}</h3>
          <p class="text-sm text-base-content/70">
            {Gettext.gettext(
              PhoenixKitWeb.Gettext,
              "Point a Graphite-plaintext collector on this source at port"
            )}
            <code class="font-mono font-semibold">{@group.port}</code>.
            <%= if @group.template do %>
              {Gettext.gettext(
                PhoenixKitWeb.Gettext,
                "Dotted metric paths are split using the template"
              )} <code>{@group.template}</code>.
            <% else %>
              {Gettext.gettext(
                PhoenixKitWeb.Gettext,
                "No template configured — the whole metric path is used verbatim, or use Graphite tag syntax (metric;label=value) for labels."
              )}
            <% end %>
          </p>
          <pre class="bg-base-200 rounded p-3 text-xs overflow-x-auto"><code>echo "metric.name 42 $(date +%s)" | nc &lt;host&gt; {@group.port}</code></pre>
        </div>
      </div>

      <div class="card bg-base-100 shadow-lg">
        <div class="card-body gap-4">
          <div :if={@metric_names == []} class="text-center text-base-content/60 py-6">
            {Gettext.gettext(
              PhoenixKitWeb.Gettext,
              "No metrics recorded yet. Once the collector starts sending data, refresh to pick a metric here."
            )}
            <div class="mt-2">
              <button type="button" class="btn btn-ghost btn-xs" phx-click="refresh_metrics">
                {Gettext.gettext(PhoenixKitWeb.Gettext, "Refresh")}
              </button>
            </div>
          </div>

          <form
            :if={@metric_names != []}
            phx-change="update_chart"
            class="flex flex-wrap gap-3 items-end"
          >
            <div class="form-control">
              <label class="label"><span class="label-text">{Gettext.gettext(PhoenixKitWeb.Gettext, "Metric")}</span></label>
              <select name="metric" class="select select-bordered select-sm">
                <option :for={name <- @metric_names} value={name} selected={name == @metric}>
                  {name}
                </option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">{Gettext.gettext(PhoenixKitWeb.Gettext, "Range")}</span></label>
              <select name="range" class="select select-bordered select-sm">
                <option
                  :for={{label, value} <- @range_options}
                  value={value}
                  selected={value == @range_seconds}
                >
                  {label}
                </option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">{Gettext.gettext(PhoenixKitWeb.Gettext, "Bucket")}</span></label>
              <select name="bucket" class="select select-bordered select-sm">
                <option
                  :for={{label, value} <- @bucket_options}
                  value={value}
                  selected={value == @bucket}
                >
                  {label}
                </option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">{Gettext.gettext(PhoenixKitWeb.Gettext, "Aggregation")}</span></label>
              <select name="agg" class="select select-bordered select-sm">
                <option :for={{label, value} <- @agg_options} value={value} selected={value == @agg}>
                  {label}
                </option>
              </select>
            </div>
          </form>

          <div :if={@chart_svg} class="w-full overflow-x-auto">
            {raw(@chart_svg)}
          </div>
        </div>
      </div>
    </div>
    """
  end
end
