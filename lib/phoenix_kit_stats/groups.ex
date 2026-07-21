defmodule PhoenixKitStats.Groups do
  @moduledoc """
  Context module for managing stats groups.

  A group is created/updated/deleted here, but reading/writing its
  actual metric data always goes through `PhoenixKitStats.Metrics` and
  `PhoenixKitStats.DatabaseManager` — this module only ever touches
  group *metadata* in Postgres, plus tells `DatabaseManager` when to
  open/close a group's Barograph database as a side effect of a status
  change.

  ## Activity logging

  Every mutating function accepts `opts \\ []`. When `actor_uuid:` is
  present in opts, the mutation is logged via `PhoenixKit.Activity.log/1`
  under the `"stats"` module key. Logging failures never crash the
  primary operation.

  ## Usage from IEx

      alias PhoenixKitStats.Groups

      {:ok, group} = Groups.create_group(%{name: "Server 1", key: "server1", port: Groups.next_available_port()})
      Groups.pause_group(group)
      Groups.resume_group(group)
      Groups.delete_group(group)
  """

  import Ecto.Query, warn: false

  require Logger

  alias PhoenixKitStats.DatabaseManager
  alias PhoenixKitStats.Schemas.Group

  @type opts :: keyword()

  defp repo, do: PhoenixKit.RepoHelper.repo()

  @doc """
  Lists all stats groups, ordered by name.

  ## Options

    * `:status` — filter by status (`"active"` or `"paused"`).
  """
  @spec list_groups(keyword()) :: [Group.t()]
  def list_groups(opts \\ []) do
    query = from(g in Group, order_by: [asc: :name])

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [g], g.status == ^status)
      end

    repo().all(query)
  end

  @doc "Fetches a group by UUID. Returns `nil` if not found."
  @spec get_group(String.t()) :: Group.t() | nil
  def get_group(uuid), do: repo().get(Group, uuid)

  @doc "Fetches a group by its slug key. Returns `nil` if not found."
  @spec get_group_by_key(String.t()) :: Group.t() | nil
  def get_group_by_key(key), do: repo().get_by(Group, key: key)

  @doc """
  Creates a stats group. Required: `:name`, `:key`, `:port`. Optional:
  `:template`, `:description`, `:settings`.

  If created with `status: "active"` (the default), opens the group's
  Barograph database + Graphite listener immediately via
  `PhoenixKitStats.DatabaseManager` — no app restart needed. A listener
  start failure (e.g. the port is unexpectedly taken) is logged but does
  not fail the create — the metadata row is the source of truth, and an
  admin can fix the port and the group will pick it up on the next
  update/resume.
  """
  @spec create_group(map(), opts) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def create_group(attrs, opts \\ []) do
    result =
      %Group{}
      |> Group.changeset(attrs)
      |> repo().insert()
      |> log_activity("stats_group.created", opts)

    with {:ok, group} <- result do
      maybe_open(group)
      {:ok, group}
    end
  end

  @doc """
  Updates a stats group. Always closes any currently-open Barograph
  listener for it first, then reopens if the (possibly new) status is
  `"active"` — this correctly handles port/template changes and status
  changes made through this function rather than `pause_group/2` /
  `resume_group/2`.
  """
  @spec update_group(Group.t(), map(), opts) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def update_group(%Group{} = group, attrs, opts \\ []) do
    result =
      group
      |> Group.changeset(attrs)
      |> repo().update()
      |> log_activity("stats_group.updated", opts)

    with {:ok, updated} <- result do
      DatabaseManager.close_group(updated.uuid)
      maybe_open(updated)
      {:ok, updated}
    end
  end

  @doc "Pauses a group: keeps its metadata and stored data, closes the Barograph DB, frees its port."
  @spec pause_group(Group.t(), opts) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def pause_group(%Group{} = group, opts \\ []) do
    result =
      group
      |> Group.changeset(%{status: "paused"})
      |> repo().update()
      |> log_activity("stats_group.paused", opts)

    with {:ok, updated} <- result do
      DatabaseManager.close_group(updated.uuid)
      {:ok, updated}
    end
  end

  @doc "Resumes a paused group: reopens its Barograph DB + Graphite listener."
  @spec resume_group(Group.t(), opts) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def resume_group(%Group{} = group, opts \\ []) do
    result =
      group
      |> Group.changeset(%{status: "active"})
      |> repo().update()
      |> log_activity("stats_group.resumed", opts)

    with {:ok, updated} <- result do
      maybe_open(updated)
      {:ok, updated}
    end
  end

  @doc """
  Permanently deletes a group: closes its Barograph DB, deletes the
  underlying `.bg` file, and removes the metadata row. Irreversible —
  callers must confirm with the user first (the admin UI does this via
  a `data-confirm` prompt).
  """
  @spec delete_group(Group.t(), opts) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def delete_group(%Group{} = group, opts \\ []) do
    DatabaseManager.close_group(group.uuid)
    delete_data_file(group)

    group
    |> repo().delete()
    |> log_activity("stats_group.deleted", opts)
  end

  @doc "Returns an `Ecto.Changeset` for tracking group changes."
  @spec change_group(Group.t(), map()) :: Ecto.Changeset.t()
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  @doc """
  Returns the lowest port in the configured `:port_range`
  (`Application.get_env(:phoenix_kit_stats, :port_range, 9100..9200)`)
  not already used by an existing group. `nil` if the range is
  exhausted. Used to prefill the "new group" form — the admin can
  override it.
  """
  @spec next_available_port() :: pos_integer() | nil
  def next_available_port do
    used = from(g in Group, select: g.port) |> repo().all() |> MapSet.new()

    port_range()
    |> Enum.find(fn port -> not MapSet.member?(used, port) end)
  end

  @doc "The configured port range groups may allocate collector ports from."
  @spec port_range() :: Range.t()
  def port_range, do: Application.get_env(:phoenix_kit_stats, :port_range, 9100..9200)

  # ── Internals ──────────────────────────────────────────────────────

  defp maybe_open(%Group{status: "active"} = group) do
    case DatabaseManager.open_group(group) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "[PhoenixKitStats.Groups] Failed to open Barograph DB for group " <>
            "#{inspect(group.key)} (port #{group.port}): #{inspect(reason)}"
        )

        :ok
    end
  end

  defp maybe_open(%Group{}), do: :ok

  defp delete_data_file(%Group{} = group) do
    case DatabaseManager.data_dir() do
      {:ok, dir} -> dir |> Path.join(group.key <> ".bg") |> File.rm()
      {:error, _} -> :ok
    end

    :ok
  rescue
    _ -> :ok
  end

  # ── Activity logging ────────────────────────────────────────────────

  defp log_activity({:ok, %Group{} = group} = ok, action, opts) do
    maybe_log_activity(action, group.uuid, opts, group_metadata(group))
    ok
  end

  defp log_activity({:error, %Ecto.Changeset{} = changeset} = err, action, opts) do
    maybe_log_activity(
      action,
      changeset_resource_uuid(changeset),
      opts,
      changeset_error_metadata(changeset)
    )

    err
  end

  defp maybe_log_activity(action, resource_uuid, opts, metadata) do
    if Code.ensure_loaded?(PhoenixKit.Activity) do
      PhoenixKit.Activity.log(%{
        action: action,
        module: "stats",
        mode: Keyword.get(opts, :mode, "manual"),
        actor_uuid: Keyword.get(opts, :actor_uuid),
        resource_type: "stats_group",
        resource_uuid: resource_uuid,
        metadata: metadata
      })
    end

    :ok
  rescue
    e in Postgrex.Error ->
      # Host hasn't run core's activity migration — swallow silently.
      if match?(%{postgres: %{code: :undefined_table}}, e) do
        :ok
      else
        Logger.warning("[Groups] Activity log failed: #{Exception.message(e)}")
        :ok
      end

    e ->
      Logger.warning("[Groups] Activity log error: #{Exception.message(e)}")
      :ok
  end

  defp changeset_resource_uuid(%Ecto.Changeset{data: data}), do: Map.get(data, :uuid)

  defp changeset_error_metadata(%Ecto.Changeset{errors: errors}) do
    %{
      "db_pending" => true,
      "error_fields" => errors |> Enum.map(fn {field, _} -> to_string(field) end) |> Enum.uniq()
    }
  end

  defp group_metadata(%Group{} = g) do
    %{"name" => g.name, "key" => g.key, "port" => g.port, "status" => g.status}
  end
end
