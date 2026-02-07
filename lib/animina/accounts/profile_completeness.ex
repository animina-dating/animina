defmodule Animina.Accounts.ProfileCompleteness do
  @moduledoc """
  Computes profile completion status for a user.

  Checks 6 items:
  1. Profile photo — approved avatar exists
  2. Profile info — height is set
  3. Location — at least 1 user location
  4. Partner preferences — preferred_partner_gender is non-empty
  5. Flags — at least 1 non-inherited user flag
  6. Moodboard — at least 2 non-deleted moodboard items
  """

  import Ecto.Query

  alias Animina.Moodboard.MoodboardItem
  alias Animina.Photos.Photo
  alias Animina.Repo
  alias Animina.Traits.UserFlag

  @total_count 6

  @doc """
  Computes profile completeness for a user.

  Returns `%{completed_count: N, total_count: 6, items: %{...}}`.
  """
  def compute(user) do
    items = %{
      profile_photo: has_approved_avatar?(user.id),
      profile_info: user.height != nil,
      location: has_location?(user),
      partner_preferences:
        user.preferred_partner_gender != nil and user.preferred_partner_gender != [],
      flags: has_flags?(user.id),
      moodboard: has_moodboard_content?(user.id)
    }

    completed_count = items |> Map.values() |> Enum.count(& &1)

    %{completed_count: completed_count, total_count: @total_count, items: items}
  end

  defp has_approved_avatar?(user_id) do
    Photo
    |> where(
      [p],
      p.owner_type == "User" and p.owner_id == ^user_id and
        p.type == "avatar" and p.state == "approved"
    )
    |> limit(1)
    |> Repo.exists?()
  end

  defp has_location?(user) do
    # user_fixture preloads locations via Accounts.list_user_locations,
    # but we check the DB to avoid requiring preloads
    Animina.Accounts.UserLocation
    |> where([l], l.user_id == ^user.id)
    |> limit(1)
    |> Repo.exists?()
  end

  defp has_flags?(user_id) do
    UserFlag
    |> where([uf], uf.user_id == ^user_id and uf.inherited == false)
    |> limit(1)
    |> Repo.exists?()
  end

  defp has_moodboard_content?(user_id) do
    count =
      MoodboardItem
      |> where([i], i.user_id == ^user_id and i.state != "deleted")
      |> Repo.aggregate(:count)

    count >= 2
  end
end
