defmodule Animina.Moodboard.Ratings do
  @moduledoc """
  Context for managing moodboard item ratings.

  Provides toggle-style rating where clicking the same value removes it,
  and clicking a different value switches to it.

  ## PubSub Notifications

  Broadcasts `{:moodboard_rating_changed, item_id}` on `"moodboard:\#{profile_user_id}"`
  after any rating mutation.
  """

  import Ecto.Query

  alias Animina.Moodboard.MoodboardItem
  alias Animina.Moodboard.MoodboardRating
  alias Animina.Repo

  @doc """
  Toggles a rating on a moodboard item.

  - If no rating exists, creates one.
  - If a rating with the same value exists, removes it.
  - If a rating with a different value exists, switches to the new value.

  Returns:
  - `{:ok, :created, rating}` — new rating created
  - `{:ok, :removed}` — existing rating removed (same value clicked again)
  - `{:ok, :switched, rating}` — rating value changed
  - `{:error, :own_item}` — user cannot rate their own item
  - `{:error, :item_not_found}` — moodboard item doesn't exist
  - `{:error, changeset}` — validation error
  """
  def toggle_rating(user_id, item_id, value) do
    with {:ok, item} <- fetch_item(item_id),
         :ok <- verify_not_owner(user_id, item) do
      existing = get_rating(user_id, item_id)

      existing
      |> apply_toggle(user_id, item_id, value)
      |> broadcast_on_success(item_id, item.user_id)
    end
  end

  defp apply_toggle(nil, user_id, item_id, value), do: create_rating(user_id, item_id, value)

  defp apply_toggle(%{value: v} = existing, _user_id, _item_id, value) when v == value,
    do: remove_rating(existing)

  defp apply_toggle(existing, _user_id, _item_id, value), do: switch_rating(existing, value)

  defp broadcast_on_success({:ok, _action, _rating} = success, item_id, owner_id) do
    broadcast_rating_changed(item_id, owner_id)
    success
  end

  defp broadcast_on_success({:ok, :removed} = success, item_id, owner_id) do
    broadcast_rating_changed(item_id, owner_id)
    success
  end

  defp broadcast_on_success(error, _item_id, _owner_id), do: error

  @doc """
  Gets a user's rating for a specific moodboard item.
  Returns the rating struct or nil.
  """
  def get_rating(user_id, item_id) do
    Repo.one(
      from r in MoodboardRating,
        where: r.user_id == ^user_id and r.moodboard_item_id == ^item_id
    )
  end

  @doc """
  Batch-loads a user's ratings for a list of moodboard item IDs.
  Returns a map of `%{item_id => value}`.
  """
  def user_ratings_for_items(_user_id, []), do: %{}

  def user_ratings_for_items(user_id, item_ids) do
    from(r in MoodboardRating,
      where: r.user_id == ^user_id and r.moodboard_item_id in ^item_ids,
      select: {r.moodboard_item_id, r.value}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Batch-loads aggregate rating counts for a list of moodboard item IDs.
  Returns a map of `%{item_id => %{-1 => count, 1 => count, 2 => count}}`.
  """
  def aggregate_ratings_for_items([]), do: %{}

  def aggregate_ratings_for_items(item_ids) do
    from(r in MoodboardRating,
      where: r.moodboard_item_id in ^item_ids,
      group_by: [r.moodboard_item_id, r.value],
      select: {r.moodboard_item_id, r.value, count(r.id)}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {item_id, value, count}, acc ->
      item_map = Map.get(acc, item_id, %{})
      Map.put(acc, item_id, Map.put(item_map, value, count))
    end)
  end

  # --- Private helpers ---

  defp fetch_item(item_id) do
    case Repo.get(MoodboardItem, item_id) do
      nil -> {:error, :item_not_found}
      item -> {:ok, item}
    end
  end

  defp verify_not_owner(user_id, item) do
    if item.user_id == user_id, do: {:error, :own_item}, else: :ok
  end

  defp create_rating(user_id, item_id, value) do
    %MoodboardRating{}
    |> MoodboardRating.changeset(%{
      user_id: user_id,
      moodboard_item_id: item_id,
      value: value
    })
    |> Repo.insert()
    |> case do
      {:ok, rating} -> {:ok, :created, rating}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp remove_rating(rating) do
    case Repo.delete(rating) do
      {:ok, _} -> {:ok, :removed}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp switch_rating(rating, new_value) do
    rating
    |> MoodboardRating.changeset(%{value: new_value})
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, :switched, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp broadcast_rating_changed(item_id, profile_user_id) do
    Phoenix.PubSub.broadcast(
      Animina.PubSub,
      "moodboard:#{profile_user_id}",
      {:moodboard_rating_changed, item_id}
    )
  end
end
