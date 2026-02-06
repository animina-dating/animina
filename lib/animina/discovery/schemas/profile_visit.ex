defmodule Animina.Discovery.Schemas.ProfileVisit do
  @moduledoc """
  Schema for tracking profile visits.
  Records when a user visits another user's moodboard/profile.
  Uses upsert to track only whether a visit happened (not count).
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_visits" do
    belongs_to :visitor, User
    belongs_to :visited, User

    timestamps(type: :utc_datetime)
  end

  def changeset(profile_visit, attrs) do
    profile_visit
    |> cast(attrs, [:visitor_id, :visited_id])
    |> validate_required([:visitor_id, :visited_id])
    |> foreign_key_constraint(:visitor_id)
    |> foreign_key_constraint(:visited_id)
    |> unique_constraint([:visitor_id, :visited_id])
  end
end
