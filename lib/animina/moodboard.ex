defmodule Animina.Moodboard do
  @moduledoc """
  Context for managing user galleries.

  This module acts as a facade, delegating to the specialized sub-module:
  - `Animina.Moodboard.Items` - CRUD operations, ordering, and visibility

  Moodboard items can be:
  - **photo**: A photo uploaded to the gallery
  - **story**: A Markdown text block (max 2000 chars)
  - **combined**: A photo with accompanying story text

  Items can be reordered via drag/drop and have visibility states:
  - **active**: Visible to all visitors
  - **hidden**: Hidden due to report (owner sees with transparency)
  - **deleted**: Soft-deleted, not visible to anyone
  """

  # --- Delegations to Items ---

  # Create operations
  defdelegate create_photo_item(user, source_path, opts \\ []), to: Animina.Moodboard.Items
  defdelegate create_story_item(user, content), to: Animina.Moodboard.Items
  defdelegate create_combined_item(user, source_path, content, opts \\ []), to: Animina.Moodboard.Items

  # Read operations
  defdelegate get_item(id), to: Animina.Moodboard.Items
  defdelegate get_item!(id), to: Animina.Moodboard.Items
  defdelegate get_item_with_preloads(id), to: Animina.Moodboard.Items
  defdelegate list_moodboard(user_id), to: Animina.Moodboard.Items
  defdelegate list_moodboard_with_hidden(user_id), to: Animina.Moodboard.Items
  defdelegate count_items(user_id, include_hidden \\ false), to: Animina.Moodboard.Items

  # Update operations
  defdelegate update_positions(user_id, item_ids_in_order), to: Animina.Moodboard.Items
  defdelegate update_story(story, content), to: Animina.Moodboard.Items
  defdelegate hide_item(item, reason), to: Animina.Moodboard.Items
  defdelegate unhide_item(item), to: Animina.Moodboard.Items
  defdelegate delete_item(item), to: Animina.Moodboard.Items
  defdelegate hard_delete_item(item), to: Animina.Moodboard.Items

  # Query helpers
  defdelegate list_moodboard_photos(user_id), to: Animina.Moodboard.Items
  defdelegate list_moodboard_stories(user_id), to: Animina.Moodboard.Items

  # Pinned item operations
  defdelegate create_pinned_intro_item(user, story_content), to: Animina.Moodboard.Items
  defdelegate link_avatar_to_pinned_item(user_id, avatar_photo_id), to: Animina.Moodboard.Items
  defdelegate unlink_avatar_from_pinned_item(user_id), to: Animina.Moodboard.Items
  defdelegate get_pinned_item(user_id), to: Animina.Moodboard.Items
end
