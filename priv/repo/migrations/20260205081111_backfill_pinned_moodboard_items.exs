defmodule Animina.Repo.Migrations.BackfillPinnedMoodboardItems do
  use Ecto.Migration

  import Ecto.Query

  # Define inline schemas to avoid dependency on application code
  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field(:language, :string)
    end
  end

  defmodule Photo do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "photos" do
      field(:owner_type, :string)
      field(:owner_id, :binary_id)
      field(:type, :string)
      field(:state, :string)
      field(:inserted_at, :utc_datetime)
    end
  end

  defmodule MoodboardItem do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "moodboard_items" do
      field(:user_id, :binary_id)
      field(:item_type, :string)
      field(:position, :integer)
      field(:state, :string)
      field(:pinned, :boolean)
      field(:inserted_at, :utc_datetime)
      field(:updated_at, :utc_datetime)
    end
  end

  defmodule MoodboardStory do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "moodboard_stories" do
      field(:moodboard_item_id, :binary_id)
      field(:content, :string)
      field(:inserted_at, :utc_datetime)
      field(:updated_at, :utc_datetime)
    end
  end

  defmodule MoodboardPhoto do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "moodboard_photos" do
      field(:moodboard_item_id, :binary_id)
      field(:photo_id, :binary_id)
      field(:inserted_at, :utc_datetime)
      field(:updated_at, :utc_datetime)
    end
  end

  @doc """
  Backfills pinned intro moodboard items for existing users who don't have one.

  This addresses production users who registered before the moodboard feature was added.
  Each user gets a pinned "combined" item at position 1 with a story prompt based on their language.
  If the user has an approved avatar, it is linked to the pinned item.
  """
  def up do
    now = DateTime.utc_now(:second)

    # Find users without a pinned moodboard item
    users_without_pinned =
      from(u in User,
        as: :user,
        where:
          not exists(
            from(mi in MoodboardItem,
              where:
                mi.user_id == parent_as(:user).id and mi.pinned == true and mi.state != "deleted"
            )
          )
      )
      |> repo().all()

    user_ids = Enum.map(users_without_pinned, & &1.id)

    # Step 1: Shift existing items to position 2+ for these users
    from(mi in MoodboardItem,
      where: mi.user_id in ^user_ids and mi.state != "deleted"
    )
    |> repo().update_all(inc: [position: 1], set: [updated_at: now])

    # Build a map of user_id -> avatar_photo_id for users with approved avatars
    avatars_by_user =
      from(p in Photo,
        where:
          p.owner_type == "User" and
            p.owner_id in ^user_ids and
            p.type == "avatar" and
            p.state == "approved",
        order_by: [desc: p.inserted_at],
        distinct: p.owner_id,
        select: {p.owner_id, p.id}
      )
      |> repo().all()
      |> Map.new()

    # Step 2, 3 & 4: Create pinned items with stories (and avatar links) for each user
    Enum.each(users_without_pinned, fn user ->
      item_id = Ecto.UUID.generate()
      story_content = default_intro_prompt(user.language)

      # Insert the pinned moodboard item
      repo().insert!(%MoodboardItem{
        id: item_id,
        user_id: user.id,
        item_type: "combined",
        position: 1,
        state: "active",
        pinned: true,
        inserted_at: now,
        updated_at: now
      })

      # Insert the moodboard story
      repo().insert!(%MoodboardStory{
        id: Ecto.UUID.generate(),
        moodboard_item_id: item_id,
        content: story_content,
        inserted_at: now,
        updated_at: now
      })

      # Link avatar photo if user has one
      case Map.get(avatars_by_user, user.id) do
        nil ->
          :ok

        avatar_photo_id ->
          repo().insert!(%MoodboardPhoto{
            id: Ecto.UUID.generate(),
            moodboard_item_id: item_id,
            photo_id: avatar_photo_id,
            inserted_at: now,
            updated_at: now
          })
      end
    end)
  end

  def down do
    now = DateTime.utc_now(:second)

    # Get all pinned items
    pinned_item_ids =
      from(mi in MoodboardItem, where: mi.pinned == true, select: mi.id)
      |> repo().all()

    # Delete photos for pinned items
    from(mp in MoodboardPhoto, where: mp.moodboard_item_id in ^pinned_item_ids)
    |> repo().delete_all()

    # Delete stories for pinned items
    from(ms in MoodboardStory, where: ms.moodboard_item_id in ^pinned_item_ids)
    |> repo().delete_all()

    # Delete pinned items
    from(mi in MoodboardItem, where: mi.pinned == true)
    |> repo().delete_all()

    # Reorder remaining items per user
    from(mi in MoodboardItem,
      where: mi.state != "deleted",
      select: %{id: mi.id, user_id: mi.user_id, position: mi.position},
      order_by: [asc: mi.user_id, asc: mi.position]
    )
    |> repo().all()
    |> Enum.group_by(& &1.user_id)
    |> Enum.each(fn {_user_id, items} ->
      items
      |> Enum.with_index(1)
      |> Enum.each(fn {item, new_position} ->
        from(mi in MoodboardItem, where: mi.id == ^item.id)
        |> repo().update_all(set: [position: new_position, updated_at: now])
      end)
    end)
  end

  defp default_intro_prompt("de"), do: "Erzähl uns etwas über dich..."
  defp default_intro_prompt(_), do: "Tell us about yourself..."
end
