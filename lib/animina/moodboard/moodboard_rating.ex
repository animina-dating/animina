defmodule Animina.Moodboard.MoodboardRating do
  @moduledoc """
  Schema for moodboard item ratings.

  Users can rate other users' moodboard items on a 3-level scale:
  - `-1` — thumbs down (dislike)
  - `+1` — thumbs up (like)
  - `+2` — double thumbs up (love)

  Each user can have at most one rating per moodboard item.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Moodboard.MoodboardItem

  @valid_values [-1, 1, 2]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "moodboard_ratings" do
    belongs_to :user, User
    belongs_to :moodboard_item, MoodboardItem

    field :value, :integer

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a moodboard rating.
  """
  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:user_id, :moodboard_item_id, :value])
    |> validate_required([:user_id, :moodboard_item_id, :value])
    |> validate_inclusion(:value, @valid_values)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:moodboard_item_id)
    |> unique_constraint([:user_id, :moodboard_item_id])
    |> check_constraint(:value, name: :valid_rating_value)
  end

  @doc """
  Returns the list of valid rating values.
  """
  def valid_values, do: @valid_values
end
