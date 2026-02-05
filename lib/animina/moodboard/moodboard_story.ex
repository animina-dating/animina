defmodule Animina.Moodboard.MoodboardStory do
  @moduledoc """
  Schema for gallery story content in Markdown format.

  Each story belongs to exactly one gallery item.
  Content is limited to 2000 characters.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Moodboard.MoodboardItem

  @max_content_length 2000

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "moodboard_stories" do
    belongs_to :moodboard_item, MoodboardItem

    field :content, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new gallery story.
  """
  def create_changeset(story, attrs) do
    story
    |> cast(attrs, [:moodboard_item_id, :content])
    |> validate_required([:moodboard_item_id, :content])
    |> validate_length(:content, max: @max_content_length)
    |> foreign_key_constraint(:moodboard_item_id)
    |> unique_constraint(:moodboard_item_id)
  end

  @doc """
  Changeset for updating a gallery story.
  """
  def update_changeset(story, attrs) do
    story
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_length(:content, max: @max_content_length)
  end

  @doc """
  Returns the maximum content length.
  """
  def max_content_length, do: @max_content_length
end
