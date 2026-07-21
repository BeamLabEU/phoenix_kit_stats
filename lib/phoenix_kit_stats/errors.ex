defmodule PhoenixKitStats.Errors do
  @moduledoc """
  Central mapping from error atoms (returned by `PhoenixKitStats.Groups`
  and used across its LiveViews) to translated human-readable strings.

  ## Supported reason shapes

    * plain atoms — `:group_not_found`, `:port_taken`, etc.
    * strings — passed through unchanged
    * anything else — rendered as `"Unexpected error: <inspect>"`

  ## Example

      iex> PhoenixKitStats.Errors.message(:group_not_found)
      "Stats group not found."
  """

  use Gettext, backend: PhoenixKitWeb.Gettext

  @doc "Translates an error reason into a user-facing string via gettext."
  @spec message(term()) :: String.t()
  def message(:group_not_found), do: gettext("Stats group not found.")
  def message(:key_taken), do: gettext("That key is already used by another group.")
  def message(:port_taken), do: gettext("That port is already used by another group.")

  def message(:port_out_of_range),
    do: gettext("Port must be within the configured port range.")

  def message(:listener_start_failed),
    do: gettext("Saved, but the collector listener failed to start on that port.")

  def message(:group_delete_failed), do: gettext("Failed to delete stats group.")

  def message(:unexpected), do: gettext("An unexpected error occurred.")

  def message(reason) when is_binary(reason), do: reason

  def message(reason) do
    gettext("Unexpected error: %{reason}", reason: inspect(reason))
  end
end
