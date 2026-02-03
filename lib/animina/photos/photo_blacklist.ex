defmodule Animina.Photos.PhotoBlacklist do
  @moduledoc """
  Schema for photo blacklist entries.

  Photos matching blacklisted dhash values (within hamming distance threshold)
  are automatically rejected without running expensive ML inference.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Photos.Photo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "photo_blacklist" do
    field :dhash, :binary
    field :reason, :string
    field :thumbnail_path, :string

    belongs_to :added_by, User
    belongs_to :source_photo, Photo
    belongs_to :source_user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a blacklist entry.
  """
  def create_changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :dhash,
      :reason,
      :thumbnail_path,
      :added_by_id,
      :source_photo_id,
      :source_user_id
    ])
    |> validate_required([:dhash])
    |> unique_constraint(:dhash)
    |> foreign_key_constraint(:added_by_id)
    |> foreign_key_constraint(:source_photo_id)
    |> foreign_key_constraint(:source_user_id)
  end
end
