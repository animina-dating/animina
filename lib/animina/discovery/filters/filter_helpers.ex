defmodule Animina.Discovery.Filters.FilterHelpers do
  @moduledoc """
  Shared helper functions for discovery filter strategies.

  Contains all filter functions that are identical between StandardFilter
  and RelaxedFilter, so each strategy only needs to define its pipeline
  and any unique filters (e.g. distance logic).
  """

  import Ecto.Query

  alias Animina.Accounts
  alias Animina.Discovery.Popularity
  alias Animina.Discovery.Schemas.{Dismissal, SuggestionView}
  alias Animina.Discovery.Settings
  alias Animina.GeoData
  alias Animina.Messaging.Schemas.ConversationClosure
  alias Animina.TimeMachine

  @doc """
  Extracts the viewer's primary location coordinates (lat/lon).

  Returns `{:ok, lat, lon}` if found, `:error` otherwise.
  """
  def get_viewer_coordinates(viewer) do
    with zip_code when not is_nil(zip_code) <- primary_zip_code(viewer),
         %{lat: lat, lon: lon} when not is_nil(lat) and not is_nil(lon) <-
           GeoData.get_city_by_zip_code(zip_code) do
      {:ok, lat, lon}
    else
      _ -> :error
    end
  end

  defdelegate compute_age(birthday), to: Accounts

  def exclude_self(query, viewer) do
    where(query, [u], u.id != ^viewer.id)
  end

  def exclude_soft_deleted(query) do
    where(query, [u], is_nil(u.deleted_at))
  end

  def filter_by_state(query) do
    # Only show users who have completed onboarding
    where(query, [u], u.state == "normal")
  end

  def filter_by_bidirectional_gender(query, viewer) do
    viewer_gender = viewer.gender
    viewer_prefs = viewer.preferred_partner_gender || []

    # Candidate's gender must be in viewer's preferences (if viewer has preferences)
    query =
      if viewer_prefs == [] do
        query
      else
        where(query, [u], u.gender in ^viewer_prefs)
      end

    # Viewer's gender must be in candidate's preferences (if candidate has preferences)
    where(
      query,
      [u],
      fragment("cardinality(?) = 0", u.preferred_partner_gender) or
        fragment("? @> ARRAY[?]::varchar[]", u.preferred_partner_gender, ^viewer_gender)
    )
  end

  def filter_by_bidirectional_age(query, viewer) do
    viewer_age = compute_age(viewer.birthday)

    if viewer_age do
      viewer_min_age = viewer_age - (viewer.partner_minimum_age_offset || 6)
      viewer_max_age = viewer_age + (viewer.partner_maximum_age_offset || 2)

      today = TimeMachine.utc_today()
      max_birthday = Date.add(today, -viewer_min_age * 365)
      min_birthday = Date.add(today, -viewer_max_age * 365)

      query
      # Candidate must be within viewer's age range
      |> where([u], u.birthday >= ^min_birthday and u.birthday <= ^max_birthday)
      # Viewer must be within candidate's age range (bidirectional)
      |> where(
        [u],
        fragment(
          "? >= (EXTRACT(YEAR FROM age(current_date, ?)) - COALESCE(?, 6))",
          ^viewer_age,
          u.birthday,
          u.partner_minimum_age_offset
        )
      )
      |> where(
        [u],
        fragment(
          "? <= (EXTRACT(YEAR FROM age(current_date, ?)) + COALESCE(?, 2))",
          ^viewer_age,
          u.birthday,
          u.partner_maximum_age_offset
        )
      )
    else
      query
    end
  end

  def filter_by_bidirectional_height(query, viewer) do
    viewer_height = viewer.height
    viewer_min_height = viewer.partner_height_min || 80
    viewer_max_height = viewer.partner_height_max || 225

    if viewer_height do
      query
      # Candidate must be within viewer's height range
      |> where(
        [u],
        is_nil(u.height) or (u.height >= ^viewer_min_height and u.height <= ^viewer_max_height)
      )
      # Viewer must be within candidate's height range (bidirectional)
      |> where(
        [u],
        is_nil(u.partner_height_min) or ^viewer_height >= u.partner_height_min
      )
      |> where(
        [u],
        is_nil(u.partner_height_max) or ^viewer_height <= u.partner_height_max
      )
    else
      query
    end
  end

  def exclude_dismissed(query, viewer) do
    dismissed_subquery =
      from(d in Dismissal,
        where: d.user_id == ^viewer.id,
        select: d.dismissed_id
      )

    where(query, [u], u.id not in subquery(dismissed_subquery))
  end

  def exclude_closed_conversations(query, viewer) do
    # Exclude users from closed (not reopened) conversations — defense-in-depth
    closed_subquery =
      from(cc in ConversationClosure,
        where:
          (cc.closed_by_id == ^viewer.id or cc.other_user_id == ^viewer.id) and
            is_nil(cc.reopened_at),
        select:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            cc.closed_by_id,
            type(^viewer.id, :binary_id),
            cc.other_user_id,
            cc.closed_by_id
          )
      )

    where(query, [u], u.id not in subquery(closed_subquery))
  end

  def exclude_recently_shown(query, viewer, list_type) do
    cutoff = Settings.cooldown_cutoff_date()

    recently_shown_subquery =
      from(sv in SuggestionView,
        where: sv.viewer_id == ^viewer.id,
        where: sv.list_type == ^list_type,
        where: sv.shown_at > ^cutoff,
        select: sv.suggested_id
      )

    where(query, [u], u.id not in subquery(recently_shown_subquery))
  end

  def maybe_exclude_incomplete_profiles(query) do
    if Settings.exclude_incomplete_profiles?() do
      query
      |> where([u], not is_nil(u.gender))
      |> where([u], not is_nil(u.height) and u.height > 0)
      |> has_approved_photo()
    else
      query
    end
  end

  def has_approved_photo(query) do
    # Check if user has at least one approved photo
    approved_photo_subquery =
      from(p in Animina.Photos.Photo,
        where: p.owner_type == "user",
        where: p.state == "approved",
        select: %{owner_id: p.owner_id, count: 1}
      )

    query
    |> join(:inner, [u], p in subquery(approved_photo_subquery), on: p.owner_id == u.id)
    |> distinct([u], u.id)
  end

  def maybe_exclude_at_daily_limit(query) do
    if Settings.popularity_enabled?() do
      users_at_limit = Popularity.users_exceeding_daily_limit()

      if Enum.empty?(users_at_limit) do
        query
      else
        where(query, [u], u.id not in ^users_at_limit)
      end
    else
      query
    end
  end

  defp primary_zip_code(%{locations: [%{position: 1, zip_code: zip} | _]}), do: zip

  defp primary_zip_code(%{locations: locations}) when is_list(locations) do
    Enum.find_value(locations, fn loc ->
      if loc.position == 1, do: loc.zip_code
    end)
  end

  defp primary_zip_code(_), do: nil
end
