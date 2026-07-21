defmodule PhoenixKitStats.Web.GroupsLive do
  @moduledoc """
  Admin list page for stats groups: create, pause/resume, delete, and
  jump to a group's chart page or edit form.
  """

  use PhoenixKitWeb, :live_view

  require Logger

  alias PhoenixKitStats.Errors
  alias PhoenixKitStats.Groups
  alias PhoenixKitStats.Paths

  @impl true
  def mount(_params, _session, socket) do
    groups = Groups.list_groups()

    {:ok,
     socket
     |> assign(
       page_title: Gettext.gettext(PhoenixKitWeb.Gettext, "Stats Groups"),
       groups_count: length(groups)
     )
     |> stream(:groups, groups, dom_id: &"group-#{&1.uuid}")}
  end

  @impl true
  def handle_event("pause", %{"uuid" => uuid}, socket) do
    with %{} = group <- Groups.get_group(uuid) || {:error, :group_not_found},
         {:ok, updated} <- Groups.pause_group(group, actor_opts(socket)) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         Gettext.gettext(PhoenixKitWeb.Gettext, "%{name} paused.", name: updated.name)
       )
       |> stream_insert(:groups, updated)}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, Errors.message(reason))}
    end
  end

  def handle_event("resume", %{"uuid" => uuid}, socket) do
    with %{} = group <- Groups.get_group(uuid) || {:error, :group_not_found},
         {:ok, updated} <- Groups.resume_group(group, actor_opts(socket)) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         Gettext.gettext(PhoenixKitWeb.Gettext, "%{name} resumed.", name: updated.name)
       )
       |> stream_insert(:groups, updated)}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, Errors.message(reason))}
    end
  end

  def handle_event("delete", %{"uuid" => uuid}, socket) do
    with %{} = group <- Groups.get_group(uuid) || {:error, :group_not_found},
         {:ok, deleted} <- Groups.delete_group(group, actor_opts(socket)) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         Gettext.gettext(PhoenixKitWeb.Gettext, "%{name} deleted.", name: deleted.name)
       )
       |> update(:groups_count, &(&1 - 1))
       |> stream_delete(:groups, deleted)}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, Errors.message(reason))}
    end
  end

  defp actor_opts(socket) do
    case socket.assigns[:phoenix_kit_current_scope] do
      %{user: %{uuid: uuid}} -> [actor_uuid: uuid]
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col w-full px-4 py-8 gap-6">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold">{Gettext.gettext(PhoenixKitWeb.Gettext, "Stats Groups")}</h2>
          <p class="text-sm text-base-content/60 mt-1">
            {Gettext.gettext(
              PhoenixKitWeb.Gettext,
              "Each group is one external data source with its own metrics store and collector port."
            )}
          </p>
        </div>
        <.link navigate={Paths.new()} class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          {Gettext.gettext(PhoenixKitWeb.Gettext, "New Group")}
        </.link>
      </div>

      <div class="card bg-base-100 shadow-lg overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>{Gettext.gettext(PhoenixKitWeb.Gettext, "Name")}</th>
              <th>{Gettext.gettext(PhoenixKitWeb.Gettext, "Key")}</th>
              <th>{Gettext.gettext(PhoenixKitWeb.Gettext, "Port")}</th>
              <th>{Gettext.gettext(PhoenixKitWeb.Gettext, "Status")}</th>
              <th class="text-right">{Gettext.gettext(PhoenixKitWeb.Gettext, "Actions")}</th>
            </tr>
          </thead>
          <tbody id="groups" phx-update="stream">
            <tr :for={{dom_id, group} <- @streams.groups} id={dom_id}>
              <td>
                <.link navigate={Paths.show(group.uuid)} class="link link-hover font-medium">
                  {group.name}
                </.link>
              </td>
              <td><code class="text-xs">{group.key}</code></td>
              <td>{group.port}</td>
              <td>
                <span class={[
                  "badge badge-sm",
                  group.status == "active" && "badge-success",
                  group.status == "paused" && "badge-ghost"
                ]}>
                  {group.status}
                </span>
              </td>
              <td class="text-right">
                <div class="flex justify-end gap-2">
                  <.link navigate={Paths.edit(group.uuid)} class="btn btn-ghost btn-xs">
                    {Gettext.gettext(PhoenixKitWeb.Gettext, "Edit")}
                  </.link>
                  <button
                    :if={group.status == "active"}
                    type="button"
                    class="btn btn-ghost btn-xs"
                    phx-click="pause"
                    phx-value-uuid={group.uuid}
                  >
                    {Gettext.gettext(PhoenixKitWeb.Gettext, "Pause")}
                  </button>
                  <button
                    :if={group.status == "paused"}
                    type="button"
                    class="btn btn-ghost btn-xs"
                    phx-click="resume"
                    phx-value-uuid={group.uuid}
                  >
                    {Gettext.gettext(PhoenixKitWeb.Gettext, "Resume")}
                  </button>
                  <button
                    type="button"
                    class="btn btn-ghost btn-xs text-error"
                    phx-click="delete"
                    phx-value-uuid={group.uuid}
                    data-confirm={
                      Gettext.gettext(
                        PhoenixKitWeb.Gettext,
                        "Delete %{name} and all of its stored metrics? This cannot be undone.",
                        name: group.name
                      )
                    }
                  >
                    {Gettext.gettext(PhoenixKitWeb.Gettext, "Delete")}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div :if={@groups_count == 0} class="p-8 text-center text-base-content/60">
          {Gettext.gettext(
            PhoenixKitWeb.Gettext,
            "No stats groups yet. Create one to start collecting metrics."
          )}
        </div>
      </div>
    </div>
    """
  end
end
