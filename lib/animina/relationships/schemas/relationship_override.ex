defmodule Animina.Relationships.Schemas.RelationshipOverride do
  @moduledoc """
  Per-user permission overrides for a relationship.

  Each field is nullable — nil means "use the status default".
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Relationships.Schemas.Relationship

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "relationship_overrides" do
    belongs_to :relationship, Relationship
    belongs_to :user, User

    field :can_see_profile, :boolean
    field :can_message_me, :boolean
    field :visible_in_discovery, :boolean

    timestamps(type: :utc_datetime)
  end

  def changeset(override, attrs) do
    override
    |> cast(attrs, [:relationship_id, :user_id, :can_see_profile, :can_message_me, :visible_in_discovery])
    |> validate_required([:relationship_id, :user_id])
    |> foreign_key_constraint(:relationship_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:relationship_id, :user_id])
  end
end
