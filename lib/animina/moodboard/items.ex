defmodule Animina.Moodboard.Items do
  @moduledoc """
  CRUD operations and queries for moodboard items.

  Handles creation of different item types (photo, story, combined),
  position ordering for drag/drop, and visibility management.
  """

  import Ecto.Query

  alias Animina.Moodboard.MoodboardItem
  alias Animina.Moodboard.MoodboardPhoto
  alias Animina.Moodboard.MoodboardStory
  alias Animina.Photos
  alias Animina.Photos.PhotoProcessor
  alias Animina.Repo

  # --- Create operations ---

  @doc """
  Creates a photo-only moodboard item.

  Uploads the photo via the Photos context with owner_type "MoodboardItem".
  """
  def create_photo_item(user, source_path, photo_opts \\ []) do
    # Skip enqueue inside transaction to avoid race condition
    opts_with_skip = Keyword.put(photo_opts, :skip_enqueue, true)

    result =
      Repo.transaction(fn ->
        position = next_position(user.id)

        with {:ok, item} <- create_item(user.id, "photo", position),
             {:ok, photo} <-
               Photos.upload_photo("MoodboardItem", item.id, source_path, opts_with_skip),
             {:ok, _moodboard_photo} <- create_moodboard_photo(item.id, photo.id) do
          {Repo.preload(item, [:moodboard_photo, moodboard_photo: :photo]), photo}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    # Enqueue photo processing AFTER transaction commits
    case result do
      {:ok, {item, photo}} ->
        PhotoProcessor.enqueue(photo)
        {:ok, item}

      error ->
        error
    end
  end

  @doc """
  Creates a story-only moodboard item with Markdown content.
  """
  def create_story_item(user, content) do
    Repo.transaction(fn ->
      position = next_position(user.id)

      with {:ok, item} <- create_item(user.id, "story", position),
           {:ok, _story} <- create_moodboard_story(item.id, content) do
        Repo.preload(item, :moodboard_story)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Creates a combined moodboard item with both photo and story.
  """
  def create_combined_item(user, source_path, content, photo_opts \\ []) do
    # Skip enqueue inside transaction to avoid race condition
    opts_with_skip = Keyword.put(photo_opts, :skip_enqueue, true)

    result =
      Repo.transaction(fn ->
        position = next_position(user.id)

        with {:ok, item} <- create_item(user.id, "combined", position),
             {:ok, photo} <-
               Photos.upload_photo("MoodboardItem", item.id, source_path, opts_with_skip),
             {:ok, _moodboard_photo} <- create_moodboard_photo(item.id, photo.id),
             {:ok, _story} <- create_moodboard_story(item.id, content) do
          {Repo.preload(item, [:moodboard_story, :moodboard_photo, moodboard_photo: :photo]),
           photo}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    # Enqueue photo processing AFTER transaction commits
    case result do
      {:ok, {item, photo}} ->
        PhotoProcessor.enqueue(photo)
        {:ok, item}

      error ->
        error
    end
  end

  defp create_item(user_id, item_type, position) do
    %MoodboardItem{}
    |> MoodboardItem.create_changeset(%{
      user_id: user_id,
      item_type: item_type,
      position: position
    })
    |> Repo.insert()
  end

  defp create_moodboard_photo(moodboard_item_id, photo_id) do
    %MoodboardPhoto{}
    |> MoodboardPhoto.create_changeset(%{
      moodboard_item_id: moodboard_item_id,
      photo_id: photo_id
    })
    |> Repo.insert()
  end

  defp create_moodboard_story(moodboard_item_id, content) do
    %MoodboardStory{}
    |> MoodboardStory.create_changeset(%{moodboard_item_id: moodboard_item_id, content: content})
    |> Repo.insert()
  end

  defp next_position(user_id) do
    max_pos =
      MoodboardItem
      |> where([i], i.user_id == ^user_id and i.state != "deleted")
      |> select([i], max(i.position))
      |> Repo.one()
      |> Kernel.||(0)

    # If user has a pinned item at position 1, start at 2 minimum
    has_pinned =
      MoodboardItem
      |> where([i], i.user_id == ^user_id and i.pinned == true and i.state != "deleted")
      |> Repo.exists?()

    min_position = if has_pinned, do: 2, else: 1
    max(max_pos + 1, min_position)
  end

  # --- Read operations ---

  @doc """
  Gets a moodboard item by ID.
  """
  def get_item(id), do: Repo.get(MoodboardItem, id)

  @doc """
  Gets a moodboard item by ID, raising if not found.
  """
  def get_item!(id), do: Repo.get!(MoodboardItem, id)

  @doc """
  Gets a moodboard item by ID with all associations preloaded.
  """
  def get_item_with_preloads(id) do
    MoodboardItem
    |> where([i], i.id == ^id)
    |> preload([:moodboard_story, moodboard_photo: :photo])
    |> Repo.one()
  end

  @doc """
  Lists active moodboard items for a user (visitor view).
  Only shows items in "active" state.
  """
  def list_moodboard(user_id) do
    MoodboardItem
    |> where([i], i.user_id == ^user_id and i.state == "active")
    |> order_by([i], asc: i.position)
    |> preload([:moodboard_story, moodboard_photo: :photo])
    |> Repo.all()
  end

  @doc """
  Lists all moodboard items for a user including hidden (owner view).
  Excludes deleted items.
  """
  def list_moodboard_with_hidden(user_id) do
    MoodboardItem
    |> where([i], i.user_id == ^user_id and i.state != "deleted")
    |> order_by([i], asc: i.position)
    |> preload([:moodboard_story, moodboard_photo: :photo])
    |> Repo.all()
  end

  @doc """
  Counts moodboard items for a user.
  """
  def count_items(user_id, include_hidden \\ false) do
    query =
      if include_hidden do
        MoodboardItem
        |> where([i], i.user_id == ^user_id and i.state != "deleted")
      else
        MoodboardItem
        |> where([i], i.user_id == ^user_id and i.state == "active")
      end

    Repo.aggregate(query, :count)
  end

  # --- Update operations ---

  @doc """
  Updates the positions of moodboard items based on a list of item IDs in desired order.

  Pinned items are excluded from reordering - they always stay at position 1.
  Non-pinned items are assigned positions starting at 2 (if there's a pinned item) or 1 (if not).

  The list should contain item IDs in the new order. Items not in the list retain their
  relative positions after the specified items.
  """
  def update_positions(user_id, item_ids_in_order) when is_list(item_ids_in_order) do
    Repo.transaction(fn ->
      # Get the pinned item ID if exists
      pinned_id =
        MoodboardItem
        |> where([i], i.user_id == ^user_id and i.pinned == true and i.state != "deleted")
        |> select([i], i.id)
        |> Repo.one()

      # Start positions at 2 if there's a pinned item, otherwise at 1
      start_position = if pinned_id, do: 2, else: 1

      # Filter out the pinned item from the list first, then assign positions
      item_ids_in_order
      |> Enum.reject(&(&1 == pinned_id))
      |> Enum.with_index(start_position)
      |> Enum.each(fn {item_id, position} ->
        MoodboardItem
        |> where([i], i.id == ^item_id and i.user_id == ^user_id and i.pinned == false)
        |> Repo.update_all(set: [position: position, updated_at: DateTime.utc_now(:second)])
      end)

      :ok
    end)
  end

  @doc """
  Updates a story's content.
  """
  def update_story(%MoodboardStory{} = story, content) do
    story
    |> MoodboardStory.update_changeset(%{content: content})
    |> Repo.update()
  end

  @doc """
  Hides a moodboard item (e.g., due to a report).
  """
  def hide_item(%MoodboardItem{} = item, reason) do
    item
    |> MoodboardItem.state_changeset("hidden", %{
      hidden_at: DateTime.utc_now(:second),
      hidden_reason: reason
    })
    |> Repo.update()
  end

  @doc """
  Unhides a moodboard item (e.g., after appeal approved).
  """
  def unhide_item(%MoodboardItem{} = item) do
    item
    |> MoodboardItem.state_changeset("active", %{
      hidden_at: nil,
      hidden_reason: nil
    })
    |> Repo.update()
  end

  @doc """
  Soft-deletes a moodboard item.
  """
  def delete_item(%MoodboardItem{} = item) do
    # First delete associated photo files if any
    item = Repo.preload(item, moodboard_photo: :photo)

    if item.moodboard_photo && item.moodboard_photo.photo do
      Photos.delete_photo(item.moodboard_photo.photo)
    end

    item
    |> MoodboardItem.state_changeset("deleted", %{})
    |> Repo.update()
  end

  @doc """
  Permanently deletes a moodboard item and its associations.
  Used for cleanup, not normal operation.
  """
  def hard_delete_item(%MoodboardItem{} = item) do
    item = Repo.preload(item, moodboard_photo: :photo)

    if item.moodboard_photo && item.moodboard_photo.photo do
      Photos.delete_photo(item.moodboard_photo.photo)
    end

    Repo.delete(item)
  end

  # --- Query helpers ---

  @doc """
  Lists all moodboard photos for a user (for rating queries).
  Returns moodboard_photo records with associated photo.
  """
  def list_moodboard_photos(user_id) do
    MoodboardPhoto
    |> join(:inner, [gp], gi in MoodboardItem, on: gp.moodboard_item_id == gi.id)
    |> where([gp, gi], gi.user_id == ^user_id and gi.state == "active")
    |> preload(:photo)
    |> Repo.all()
  end

  @doc """
  Lists all moodboard stories for a user.
  """
  def list_moodboard_stories(user_id) do
    MoodboardStory
    |> join(:inner, [gs], gi in MoodboardItem, on: gs.moodboard_item_id == gi.id)
    |> where([gs, gi], gi.user_id == ^user_id and gi.state == "active")
    |> Repo.all()
  end

  # --- Pinned item operations ---

  @doc """
  Creates a pinned intro item at position 1 for a user.

  This is the "About Me" combined item that syncs with the user's avatar.
  It starts with just a story prompt; the photo is linked when the user uploads an avatar.

  Returns `{:error, :already_exists}` if user already has a pinned item.
  """
  def create_pinned_intro_item(user, story_content) do
    # Check if pinned item already exists
    if get_pinned_item(user.id) do
      {:error, :already_exists}
    else
      Repo.transaction(fn ->
        # Shift existing items to make room for position 1
        shift_positions_for_pinned(user.id)

        with {:ok, item} <- create_pinned_item(user.id, story_content) do
          Repo.preload(item, :moodboard_story)
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  defp shift_positions_for_pinned(user_id) do
    # Only shift non-pinned items (pinned items must stay at position 1)
    MoodboardItem
    |> where([i], i.user_id == ^user_id and i.state != "deleted" and i.pinned == false)
    |> Repo.update_all(inc: [position: 1])
  end

  defp create_pinned_item(user_id, story_content) do
    with {:ok, item} <-
           %MoodboardItem{}
           |> MoodboardItem.create_changeset(%{
             user_id: user_id,
             item_type: "combined",
             position: 1,
             pinned: true
           })
           |> Repo.insert(),
         {:ok, _story} <- create_moodboard_story(item.id, story_content) do
      {:ok, item}
    end
  end

  @doc """
  Links an avatar photo to the user's pinned intro item.

  Creates a MoodboardPhoto record pointing to the avatar Photo.
  If a MoodboardPhoto already exists, updates it to point to the new avatar.
  """
  def link_avatar_to_pinned_item(user_id, avatar_photo_id) do
    case get_pinned_item(user_id) do
      nil ->
        {:error, :no_pinned_item}

      item ->
        item = Repo.preload(item, :moodboard_photo)

        case item.moodboard_photo do
          nil ->
            # Create new link
            %MoodboardPhoto{}
            |> MoodboardPhoto.create_changeset(%{
              moodboard_item_id: item.id,
              photo_id: avatar_photo_id
            })
            |> Repo.insert()

          existing ->
            # Update existing link
            existing
            |> MoodboardPhoto.update_changeset(%{photo_id: avatar_photo_id})
            |> Repo.update()
        end
    end
  end

  @doc """
  Unlinks the avatar from the user's pinned intro item.

  Deletes the MoodboardPhoto record but keeps the item with its story.
  """
  def unlink_avatar_from_pinned_item(user_id) do
    case get_pinned_item(user_id) do
      nil ->
        :ok

      item ->
        item = Repo.preload(item, :moodboard_photo)

        if item.moodboard_photo do
          Repo.delete(item.moodboard_photo)
        end

        :ok
    end
  end

  @doc """
  Gets the pinned item for a user.
  """
  def get_pinned_item(user_id) do
    MoodboardItem
    |> where([i], i.user_id == ^user_id and i.pinned == true and i.state != "deleted")
    |> preload([:moodboard_story, moodboard_photo: :photo])
    |> Repo.one()
  end

  @doc """
  Updates the positions of moodboard items based on a list of item IDs in desired order.
  Pinned items are excluded from reordering - they always stay at position 1.

  The list should contain item IDs in the new order. Items not in the list retain their
  relative positions after the specified items.
  """
  def update_positions_excluding_pinned(user_id, item_ids_in_order)
      when is_list(item_ids_in_order) do
    Repo.transaction(fn ->
      # Get the pinned item to exclude it
      pinned_item = get_pinned_item(user_id)
      pinned_id = pinned_item && pinned_item.id

      # Filter out pinned item and update positions starting at 2
      item_ids_in_order
      |> Enum.reject(&(&1 == pinned_id))
      |> Enum.with_index(2)
      |> Enum.each(fn {item_id, position} ->
        MoodboardItem
        |> where([i], i.id == ^item_id and i.user_id == ^user_id and i.pinned == false)
        |> Repo.update_all(set: [position: position, updated_at: DateTime.utc_now(:second)])
      end)

      :ok
    end)
  end
end
