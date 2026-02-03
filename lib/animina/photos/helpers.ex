defmodule Animina.Photos.Helpers do
  @moduledoc """
  Shared helper functions for photo-related operations.
  """

  alias Animina.Photos.AuditLog
  alias Animina.Photos.Blacklist
  alias Animina.Photos.Photo

  @doc """
  Determines the actor type for audit logging based on the user's roles.
  Returns "admin" if the user has the admin role, otherwise "moderator".
  """
  def determine_actor_type(user) do
    if Animina.Accounts.has_role?(user, "admin"), do: "admin", else: "moderator"
  end

  @doc """
  Conditionally adds a photo's dhash to the blacklist.

  Returns `:ok` on success or if `add_to_blacklist` is false.
  Returns `{:error, :no_dhash}` if the photo has no dhash.
  """
  def maybe_add_to_blacklist(_photo, false, _reason, _reviewer, _actor_type), do: :ok

  def maybe_add_to_blacklist(%Photo{dhash: nil}, true, _reason, _reviewer, _actor_type),
    do: {:error, :no_dhash}

  def maybe_add_to_blacklist(%Photo{dhash: dhash} = photo, true, reason, reviewer, actor_type) do
    effective_reason = if reason in [nil, ""], do: nil, else: reason

    case Blacklist.add_to_blacklist(dhash, effective_reason, reviewer, photo) do
      {:ok, _entry} ->
        AuditLog.log_event(photo, "blacklist_added", actor_type, reviewer.id, %{reason: reason})
        :ok

      {:error, _} = error ->
        error
    end
  end
end
