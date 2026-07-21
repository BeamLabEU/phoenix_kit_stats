defmodule PhoenixKitStats.Web.GroupFormLive do
  @moduledoc "Create/edit form for stats groups: name, key, port, template, description."

  use PhoenixKitWeb, :live_view

  require Logger

  alias PhoenixKitStats.Errors
  alias PhoenixKitStats.Groups
  alias PhoenixKitStats.Paths
  alias PhoenixKitStats.Schemas.Group

  @impl true
  def mount(params, _session, socket) do
    action = socket.assigns.live_action

    case load_group(action, params) do
      {:not_found, uuid} ->
        Logger.info("Stats group not found for edit: #{uuid}")

        {:ok,
         socket
         |> put_flash(:error, Errors.message(:group_not_found))
         |> push_navigate(to: Paths.index())}

      {group, changeset} ->
        {:ok,
         socket
         |> assign(page_title: page_title(action, group), action: action, group: group)
         |> assign_form(changeset)}
    end
  end

  defp load_group(:new, _params) do
    g = %Group{port: Groups.next_available_port()}
    {g, Groups.change_group(g)}
  end

  defp load_group(:edit, params) do
    case Groups.get_group(params["uuid"]) do
      nil -> {:not_found, params["uuid"]}
      g -> {g, Groups.change_group(g)}
    end
  end

  defp page_title(:new, _group), do: Gettext.gettext(PhoenixKitWeb.Gettext, "New Stats Group")

  defp page_title(:edit, group),
    do: Gettext.gettext(PhoenixKitWeb.Gettext, "Edit %{name}", name: group.name)

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, changeset: changeset, form: to_form(changeset, as: :group))
  end

  @impl true
  def handle_event("validate", %{"group" => params}, socket) do
    changeset =
      socket.assigns.group
      |> Groups.change_group(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"group" => params}, socket) do
    save_group(socket, socket.assigns.action, params)
  end

  defp save_group(socket, :new, params) do
    case Groups.create_group(params, actor_opts(socket)) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, Gettext.gettext(PhoenixKitWeb.Gettext, "Stats group created."))
         |> push_navigate(to: Paths.show(group.uuid))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp save_group(socket, :edit, params) do
    case Groups.update_group(socket.assigns.group, params, actor_opts(socket)) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, Gettext.gettext(PhoenixKitWeb.Gettext, "Stats group updated."))
         |> push_navigate(to: Paths.show(group.uuid))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
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
      <div>
        <h2 class="text-2xl font-bold">{@page_title}</h2>
        <p class="text-sm text-base-content/60 mt-1">
          {Gettext.gettext(
            PhoenixKitWeb.Gettext,
            "A stats group is one external data source (e.g. a server) with its own metrics store and collector port."
          )}
        </p>
      </div>

      <div class="max-w-2xl w-full">
        <.form for={@form} action="#" phx-change="validate" phx-submit="save">
          <div class="card bg-base-100 shadow-lg">
            <div class="card-body flex flex-col gap-5">
              <.input
                field={@form[:name]}
                type="text"
                label={Gettext.gettext(PhoenixKitWeb.Gettext, "Name")}
                placeholder="Server 1"
                required
              />

              <div>
                <.input
                  field={@form[:key]}
                  type="text"
                  label={Gettext.gettext(PhoenixKitWeb.Gettext, "Key")}
                  placeholder="server1"
                  required
                />
                <span class="label-text-alt text-base-content/50">
                  {Gettext.gettext(
                    PhoenixKitWeb.Gettext,
                    "Lowercase letters, numbers, underscores, hyphens. Used as the metrics filename — avoid changing it once a collector is configured against it."
                  )}
                </span>
              </div>

              <div>
                <.input
                  field={@form[:port]}
                  type="number"
                  label={Gettext.gettext(PhoenixKitWeb.Gettext, "Collector Port")}
                  required
                />
                <span class="label-text-alt text-base-content/50">
                  {Gettext.gettext(
                    PhoenixKitWeb.Gettext,
                    "The TCP port the collector sends Graphite plaintext lines to. Must be free and reachable from the collector's network — Graphite has no built-in authentication, so restrict access at the firewall/VPN level."
                  )}
                </span>
              </div>

              <div>
                <.input
                  field={@form[:template]}
                  type="text"
                  label={Gettext.gettext(PhoenixKitWeb.Gettext, "Graphite Template (optional)")}
                  placeholder="*.forklift.metric"
                />
                <span class="label-text-alt text-base-content/50">
                  {Gettext.gettext(
                    PhoenixKitWeb.Gettext,
                    "Splits dotted metric paths into labels. Leave blank if the collector uses tag syntax (metric;label=value) or sends bare metric names."
                  )}
                </span>
              </div>

              <.textarea
                field={@form[:description]}
                label={Gettext.gettext(PhoenixKitWeb.Gettext, "Description")}
                rows="3"
              />
            </div>

            <div class="card-body flex flex-col gap-5 pt-0">
              <div class="divider my-0"></div>
              <div class="flex justify-end gap-3">
                <.link navigate={Paths.index()} class="btn btn-ghost">
                  {Gettext.gettext(PhoenixKitWeb.Gettext, "Cancel")}
                </.link>
                <button
                  type="submit"
                  class="btn btn-primary phx-submit-loading:opacity-75"
                  phx-disable-with={
                    if @action == :new,
                      do: Gettext.gettext(PhoenixKitWeb.Gettext, "Creating..."),
                      else: Gettext.gettext(PhoenixKitWeb.Gettext, "Saving...")
                  }
                >
                  {if @action == :new,
                    do: Gettext.gettext(PhoenixKitWeb.Gettext, "Create Group"),
                    else: Gettext.gettext(PhoenixKitWeb.Gettext, "Save Changes")}
                </button>
              </div>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
