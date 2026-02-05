defmodule Animina.Moodboard.MoodboardPhoto do
  @moduledoc """
  Junction schema linking moodboard items to photos.

  Each moodboard photo belongs to exactly one moodboard item
  and references one photo from the Photos context.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Moodboard.MoodboardItem
  alias Animina.Photos.Photo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "moodboard_photos" do
    belongs_to :moodboard_item, MoodboardItem
    belongs_to :photo, Photo

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new moodboard photo link.
  """
  def create_changeset(moodboard_photo, attrs) do
    moodboard_photo
    |> cast(attrs, [:moodboard_item_id, :photo_id])
    |> validate_required([:moodboard_item_id, :photo_id])
    |> foreign_key_constraint(:moodboard_item_id)
    |> foreign_key_constraint(:photo_id)
    |> unique_constraint(:moodboard_item_id)
  end

  @doc """
  Changeset for updating the photo link (e.g., when avatar changes).
  """
  def update_changeset(moodboard_photo, attrs) do
    moodboard_photo
    |> cast(attrs, [:photo_id])
    |> validate_required([:photo_id])
    |> foreign_key_constraint(:photo_id)
  end
end
