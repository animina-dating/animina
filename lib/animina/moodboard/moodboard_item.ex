defmodule Animina.Moodboard.MoodboardItem do
  @moduledoc """
  Schema for gallery items - the core container for gallery content.

  Moodboard items can be photos, stories (Markdown), or combined (photo + story).
  Items can be reordered via drag/drop and have visibility states.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Moodboard.MoodboardPhoto
  alias Animina.Moodboard.MoodboardStory

  @valid_item_types ~w(photo story combined)
  @valid_states ~w(active hidden deleted)
  @valid_state_transitions %{
    "active" => ["hidden", "deleted"],
    "hidden" => ["active", "deleted"],
    "deleted" => []
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "moodboard_items" do
    belongs_to :user, User
    has_one :moodboard_story, MoodboardStory
    has_one :moodboard_photo, MoodboardPhoto

    field :item_type, :string
    field :position, :integer, default: 0
    field :state, :string, default: "active"
    field :pinned, :boolean, default: false
    field :hidden_at, :utc_datetime
    field :hidden_reason, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new gallery item.
  """
  def create_changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :item_type, :position, :pinned])
    |> validate_required([:user_id, :item_type])
    |> validate_inclusion(:item_type, @valid_item_types)
    |> validate_inclusion(:state, @valid_states)
    |> foreign_key_constraint(:user_id)
    |> check_constraint(:pinned, name: :pinned_must_be_position_one)
    |> unique_constraint(:user_id, name: :moodboard_items_user_pinned_unique)
  end

  @doc """
  Changeset for updating position.
  """
  def position_changeset(item, attrs) do
    item
    |> cast(attrs, [:position])
    |> validate_required([:position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end

  @doc """
  Changeset for transitioning to a new state.
  """
  def state_changeset(item, new_state, attrs \\ %{}) do
    current_state = item.state
    allowed = Map.get(@valid_state_transitions, current_state, [])

    if new_state in allowed do
      item
      |> cast(attrs, [:hidden_at, :hidden_reason])
      |> put_change(:state, new_state)
    else
      item
      |> change()
      |> add_error(:state, "cannot transition from #{current_state} to #{new_state}")
    end
  end

  @doc """
  Returns the list of valid item types.
  """
  def valid_item_types, do: @valid_item_types

  @doc """
  Returns the list of valid states.
  """
  def valid_states, do: @valid_states

  @doc """
  Returns the valid state transitions map.
  """
  def valid_state_transitions, do: @valid_state_transitions
end
