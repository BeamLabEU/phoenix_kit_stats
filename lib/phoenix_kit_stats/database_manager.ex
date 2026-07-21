defmodule PhoenixKitStats.DatabaseManager do
  @moduledoc """
  Owns every stats group's open Barograph database — a SQLite file plus
  a Graphite plaintext ingest listener bound to the group's configured
  port.

  Supervised as a `children/0` entry on `PhoenixKitStats`, so it starts
  automatically inside the host app's `PhoenixKit.Supervisor`
  (`PhoenixKit.ModuleRegistry.static_children/0` collects it) — no
  host-app supervision tree changes needed.

  At boot, every `status: "active"` group is opened. A single group's
  port-bind failure (e.g. the port is already taken by something else)
  is logged as a warning and skipped — it must not crash the whole app.
  Group create/update/pause/resume/delete call back into this GenServer
  at runtime, so no app restart is ever required.
  """

  use GenServer

  require Logger

  alias PhoenixKitStats.Groups
  alias PhoenixKitStats.Schemas.Group

  @name __MODULE__

  # ── Public API ─────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @name))
  end

  @doc """
  The directory Barograph `.bg` files are stored under. Requires
  `config :phoenix_kit_stats, data_dir: "..."` — checked lazily, only
  when a group actually needs opening, so a host that never enables any
  group never needs to set it.
  """
  @spec data_dir() :: {:ok, String.t()} | {:error, :not_configured}
  def data_dir do
    case Application.get_env(:phoenix_kit_stats, :data_dir) do
      nil -> {:error, :not_configured}
      dir -> {:ok, dir}
    end
  end

  @doc "Opens (or re-opens) a group's Barograph DB + Graphite listener."
  @spec open_group(Group.t(), GenServer.server()) :: :ok | {:error, term()}
  def open_group(%Group{} = group, server \\ @name) do
    GenServer.call(server, {:open, group})
  end

  @doc "Closes a group's Barograph DB (if open) and frees its port. No-op if not open."
  @spec close_group(String.t(), GenServer.server()) :: :ok
  def close_group(group_uuid, server \\ @name) do
    GenServer.call(server, {:close, group_uuid})
  end

  @doc "Returns the open Barograph db handle for a group, or `{:error, :not_open}`."
  @spec get_db(String.t(), GenServer.server()) :: {:ok, Barograph.db()} | {:error, :not_open}
  def get_db(group_uuid, server \\ @name) do
    GenServer.call(server, {:get_db, group_uuid})
  end

  # ── GenServer callbacks ────────────────────────────────────────────

  @impl true
  def init(_opts) do
    # Defer the Repo-dependent group scan until after the supervisor
    # considers this child started, avoiding boot-ordering coupling to Ecto.
    {:ok, %{}, {:continue, :load_groups}}
  end

  @impl true
  def handle_continue(:load_groups, state) do
    state =
      Groups.list_groups(status: "active")
      |> Enum.reduce(state, fn group, acc ->
        case do_open(group) do
          {:ok, db} ->
            Map.put(acc, group.uuid, db)

          {:error, reason} ->
            Logger.warning(
              "[PhoenixKitStats.DatabaseManager] Failed to open group " <>
                "#{inspect(group.key)} (port #{group.port}): #{inspect(reason)} — this " <>
                "group won't accept new samples until fixed and reopened."
            )

            acc
        end
      end)

    {:noreply, state}
  rescue
    e ->
      Logger.warning(
        "[PhoenixKitStats.DatabaseManager] Could not load groups at boot " <>
          "(Repo unavailable?): #{Exception.message(e)}"
      )

      {:noreply, state}
  end

  @impl true
  def handle_call({:open, group}, _from, state) do
    state = do_close(state, group.uuid)

    case do_open(group) do
      {:ok, db} -> {:reply, :ok, Map.put(state, group.uuid, db)}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:close, group_uuid}, _from, state) do
    {:reply, :ok, do_close(state, group_uuid)}
  end

  def handle_call({:get_db, group_uuid}, _from, state) do
    case Map.fetch(state, group_uuid) do
      {:ok, db} -> {:reply, {:ok, db}, state}
      :error -> {:reply, {:error, :not_open}, state}
    end
  end

  # ── Internals ──────────────────────────────────────────────────────

  defp do_open(%Group{} = group) do
    with {:ok, dir} <- data_dir(),
         :ok <- File.mkdir_p(dir) do
      path = Path.join(dir, group.key <> ".bg")

      Barograph.open(path,
        ingest: [graphite: [port: group.port, template: group.template]]
      )
    end
  end

  defp do_close(state, group_uuid) do
    case Map.fetch(state, group_uuid) do
      {:ok, db} ->
        Barograph.close(db)
        Map.delete(state, group_uuid)

      :error ->
        state
    end
  end
end
