defmodule Animina.Photos.PhotoAppeal do
  @moduledoc """
  Schema for photo review appeals.

  When a photo is rejected (no_face_error, error), users can request a human review.
  Moderators can then approve or reject the appeal.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Photos.Photo

  @valid_statuses ~w(pending resolved)
  @valid_resolutions ~w(approved rejected)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "photo_appeals" do
    belongs_to :photo, Photo
    belongs_to :user, User
    belongs_to :reviewer, User

    field :status, :string, default: "pending"
    field :appeal_reason, :string
    field :reviewer_notes, :string
    field :resolution, :string
    field :resolved_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new appeal.
  """
  def create_changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:photo_id, :user_id, :appeal_reason])
    |> validate_required([:photo_id, :user_id])
    |> foreign_key_constraint(:photo_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:photo_id, :status],
      name: :photo_appeals_photo_id_status_index,
      message: "already has a pending appeal"
    )
  end

  @doc """
  Changeset for resolving an appeal.
  """
  def resolve_changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:reviewer_id, :reviewer_notes, :resolution])
    |> validate_required([:reviewer_id, :resolution])
    |> validate_inclusion(:resolution, @valid_resolutions)
    |> put_change(:status, "resolved")
    |> put_change(:resolved_at, DateTime.utc_now(:second))
    |> foreign_key_constraint(:reviewer_id)
  end

  @doc """
  Returns the list of valid statuses.
  """
  def valid_statuses, do: @valid_statuses

  @doc """
  Returns the list of valid resolutions.
  """
  def valid_resolutions, do: @valid_resolutions
end
