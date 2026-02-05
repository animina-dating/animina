defmodule Animina.MoodboardFixtures do
  @moduledoc """
  Test helpers for creating moodboard entities.
  """

  alias Animina.Moodboard
  alias Animina.Moodboard.MoodboardItem
  alias Animina.Moodboard.MoodboardPhoto
  alias Animina.Moodboard.MoodboardStory
  alias Animina.Repo

  import Animina.PhotosFixtures, only: [approved_photo_fixture: 1]

  @doc """
  Creates a moodboard item directly in the database.
  """
  def moodboard_item_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        user_id: Ecto.UUID.generate(),
        item_type: "photo",
        position: 0,
        state: "active"
      })

    {:ok, item} =
      %MoodboardItem{}
      |> MoodboardItem.create_changeset(attrs)
      |> Repo.insert()

    item
  end

  @doc """
  Creates a photo moodboard item with an associated approved photo.
  """
  def photo_moodboard_item_fixture(user, attrs \\ %{}) do
    item = moodboard_item_fixture(Map.merge(%{user_id: user.id, item_type: "photo"}, attrs))

    photo =
      approved_photo_fixture(%{
        owner_type: "MoodboardItem",
        owner_id: item.id,
        type: "moodboard"
      })

    {:ok, moodboard_photo} =
      %MoodboardPhoto{}
      |> MoodboardPhoto.create_changeset(%{moodboard_item_id: item.id, photo_id: photo.id})
      |> Repo.insert()

    item
    |> Repo.preload(moodboard_photo: :photo)
    |> Map.put(:moodboard_photo, %{moodboard_photo | photo: photo})
  end

  @doc """
  Creates a story moodboard item with Markdown content.
  """
  def story_moodboard_item_fixture(user, content \\ "# Hello\n\nThis is my story.", attrs \\ %{}) do
    item = moodboard_item_fixture(Map.merge(%{user_id: user.id, item_type: "story"}, attrs))

    {:ok, story} =
      %MoodboardStory{}
      |> MoodboardStory.create_changeset(%{moodboard_item_id: item.id, content: content})
      |> Repo.insert()

    item
    |> Repo.preload(:moodboard_story)
    |> Map.put(:moodboard_story, story)
  end

  @doc """
  Creates a combined moodboard item with both photo and story.
  """
  def combined_moodboard_item_fixture(user, content \\ "Caption for my photo", attrs \\ %{}) do
    item = moodboard_item_fixture(Map.merge(%{user_id: user.id, item_type: "combined"}, attrs))

    photo =
      approved_photo_fixture(%{
        owner_type: "MoodboardItem",
        owner_id: item.id,
        type: "moodboard"
      })

    {:ok, moodboard_photo} =
      %MoodboardPhoto{}
      |> MoodboardPhoto.create_changeset(%{moodboard_item_id: item.id, photo_id: photo.id})
      |> Repo.insert()

    {:ok, story} =
      %MoodboardStory{}
      |> MoodboardStory.create_changeset(%{moodboard_item_id: item.id, content: content})
      |> Repo.insert()

    item
    |> Repo.preload([:moodboard_story, moodboard_photo: :photo])
    |> Map.put(:moodboard_photo, %{moodboard_photo | photo: photo})
    |> Map.put(:moodboard_story, story)
  end

  @doc """
  Creates a hidden moodboard item.
  """
  def hidden_moodboard_item_fixture(user, reason \\ "inappropriate_adult") do
    item = moodboard_item_fixture(%{user_id: user.id, item_type: "photo"})

    {:ok, hidden_item} = Moodboard.hide_item(item, reason)
    hidden_item
  end
end
