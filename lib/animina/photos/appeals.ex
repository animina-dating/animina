defmodule Animina.Photos.Appeals do
  @moduledoc """
  Photo appeal management for rejected photos.

  Handles the appeal workflow where users can request review of
  rejected photos by moderators.
  """

  import Ecto.Query

  alias Animina.Photos
  alias Animina.Photos.AuditLog
  alias Animina.Photos.Blacklist
  alias Animina.Photos.Helpers
  alias Animina.Photos.Photo
  alias Animina.Photos.PhotoAppeal
  alias Animina.Repo
  alias Animina.Repo.Paginator

  @doc """
  Creates an appeal for a rejected photo.
  Transitions the photo to `appeal_pending` state.
  """
  def create_appeal(%Photo{} = photo, user, reason \\ nil) do
    Repo.transaction(fn ->
      attrs = %{
        photo_id: photo.id,
        user_id: user.id,
        appeal_reason: reason
      }

      with {:ok, appeal} <-
             %PhotoAppeal{}
             |> PhotoAppeal.create_changeset(attrs)
             |> Repo.insert(),
           {:ok, updated_photo} <- Photos.transition_photo(photo, "appeal_pending"),
           {:ok, _log} <-
             AuditLog.log_event(updated_photo, "appeal_created", "user", user.id, %{
               appeal_reason: reason
             }) do
        %{appeal: appeal, photo: updated_photo}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Lists all pending appeals, newest first.
  """
  def list_pending_appeals do
    PhotoAppeal
    |> where([a], a.status == "pending")
    |> order_by([a], desc: a.inserted_at)
    |> preload([:photo, :user])
    |> Repo.all()
  end

  @doc """
  Lists pending appeals with pagination.

  Returns a map with:
    - entries: list of appeals for the current page
    - page: current page number
    - per_page: items per page
    - total_count: total number of pending appeals
    - total_pages: total number of pages

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - items per page (default: 50)
    * `:viewer_id` - if provided, excludes appeals for the viewer's own photos
      unless they are the only moderator in the system
  """
  def list_pending_appeals_paginated(opts \\ []) do
    viewer_id = Keyword.get(opts, :viewer_id)

    PhotoAppeal
    |> where([a], a.status == "pending")
    |> maybe_exclude_own_appeals(viewer_id)
    |> order_by([a], desc: a.inserted_at)
    |> Paginator.paginate(
      page: opts[:page],
      per_page: opts[:per_page],
      max_per_page: 250,
      preload: [:photo, :user]
    )
  end

  defp maybe_exclude_own_appeals(query, nil), do: query

  defp maybe_exclude_own_appeals(query, viewer_id) do
    if Animina.Accounts.count_users_with_role("moderator") > 1 do
      where(query, [a], a.user_id != ^viewer_id)
    else
      query
    end
  end

  @doc """
  Returns the count of pending appeals.

  ## Options

    * `:viewer_id` - if provided, excludes appeals for the viewer's own photos
      unless they are the only moderator in the system
  """
  def count_pending_appeals(opts \\ []) do
    viewer_id = Keyword.get(opts, :viewer_id)

    PhotoAppeal
    |> where([a], a.status == "pending")
    |> maybe_exclude_own_appeals(viewer_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Resolves multiple appeals in a single operation.

  Returns `{:ok, %{resolved: n, failed: n}}` with counts of successful
  and failed resolutions.

  ## Options

    * `:add_to_blacklist` - if true, adds rejected photos' dhashes to blacklist
    * `:blacklist_reason` - reason for blacklisting
    * `:reviewer_notes` - notes to add to each appeal
  """
  def bulk_resolve_appeals(appeal_ids, reviewer, resolution, opts \\ []) do
    add_to_blacklist = Keyword.get(opts, :add_to_blacklist, false)
    blacklist_reason = Keyword.get(opts, :blacklist_reason)
    reviewer_notes = Keyword.get(opts, :reviewer_notes)

    resolve_opts = [
      add_to_blacklist: add_to_blacklist,
      blacklist_reason: blacklist_reason,
      reviewer_notes: reviewer_notes
    ]

    results = Enum.map(appeal_ids, &resolve_single_appeal(&1, reviewer, resolution, resolve_opts))

    resolved = Enum.count(results, &(&1 == :ok))
    failed = length(results) - resolved

    {:ok, %{resolved: resolved, failed: failed}}
  end

  defp resolve_single_appeal(id, reviewer, resolution, resolve_opts) do
    case get_appeal(id) do
      nil -> {:error, :not_found}
      %PhotoAppeal{status: "resolved"} -> {:error, :already_resolved}
      appeal -> do_resolve_appeal(appeal, reviewer, resolution, resolve_opts)
    end
  end

  defp do_resolve_appeal(appeal, reviewer, resolution, resolve_opts) do
    case resolve_appeal(appeal, reviewer, resolution, resolve_opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets an appeal by ID.
  """
  def get_appeal(id) do
    PhotoAppeal
    |> preload([:photo, :user, :reviewer])
    |> Repo.get(id)
  end

  @doc """
  Gets an appeal by ID, raising if not found.
  """
  def get_appeal!(id) do
    PhotoAppeal
    |> preload([:photo, :user, :reviewer])
    |> Repo.get!(id)
  end

  @doc """
  Resolves an appeal.

  ## Options

    * `:add_to_blacklist` - if true, adds the photo's dhash to the blacklist
    * `:remove_from_blacklist` - if true, removes the photo's dhash from the blacklist
    * `:blacklist_reason` - reason for blacklisting (required if add_to_blacklist is true)
    * `:reviewer_notes` - notes to add to the appeal
  """
  def resolve_appeal(%PhotoAppeal{} = appeal, reviewer, resolution, opts \\ []) do
    add_to_blacklist = Keyword.get(opts, :add_to_blacklist, false)
    remove_from_blacklist = Keyword.get(opts, :remove_from_blacklist, false)
    blacklist_reason = Keyword.get(opts, :blacklist_reason)
    reviewer_notes = Keyword.get(opts, :reviewer_notes)

    new_state = resolution_to_photo_state(resolution)
    event_type = resolution_to_event_type(resolution)

    Repo.transaction(fn ->
      photo = Repo.get!(Photo, appeal.photo_id)
      actor_type = Helpers.determine_actor_type(reviewer)

      resolve_attrs = %{
        reviewer_id: reviewer.id,
        resolution: resolution,
        reviewer_notes: reviewer_notes
      }

      with {:ok, resolved_appeal} <-
             appeal
             |> PhotoAppeal.resolve_changeset(resolve_attrs)
             |> Repo.update(),
           {:ok, updated_photo} <- Photos.transition_photo(photo, new_state),
           {:ok, _log} <-
             AuditLog.log_event(updated_photo, event_type, actor_type, reviewer.id, %{
               notes: reviewer_notes
             }),
           :ok <-
             Helpers.maybe_add_to_blacklist(
               updated_photo,
               add_to_blacklist,
               blacklist_reason,
               reviewer,
               actor_type
             ),
           :ok <-
             maybe_remove_from_blacklist(
               updated_photo,
               remove_from_blacklist,
               reviewer,
               actor_type
             ) do
        %{appeal: resolved_appeal, photo: updated_photo}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp maybe_remove_from_blacklist(_photo, false, _reviewer, _actor_type), do: :ok

  defp maybe_remove_from_blacklist(%Photo{dhash: nil}, true, _reviewer, _actor_type), do: :ok

  defp maybe_remove_from_blacklist(%Photo{dhash: dhash} = photo, true, reviewer, actor_type) do
    case Blacklist.get_blacklist_entry_by_dhash(dhash) do
      nil ->
        :ok

      entry ->
        case Blacklist.remove_from_blacklist(entry) do
          {:ok, _} ->
            AuditLog.log_event(photo, "blacklist_removed", actor_type, reviewer.id, %{
              reason: "Approved via appeal"
            })

            :ok

          {:error, _} = error ->
            error
        end
    end
  end

  defp resolution_to_photo_state("approved"), do: "approved"
  defp resolution_to_photo_state(_), do: "appeal_rejected"

  defp resolution_to_event_type("approved"), do: "appeal_approved"
  defp resolution_to_event_type(_), do: "appeal_rejected"

  @doc """
  Checks if a photo has a pending appeal.
  """
  def has_pending_appeal?(photo_id) do
    PhotoAppeal
    |> where([a], a.photo_id == ^photo_id and a.status == "pending")
    |> Repo.exists?()
  end
end
