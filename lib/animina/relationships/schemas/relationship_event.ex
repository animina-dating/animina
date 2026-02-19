defmodule Animina.Relationships.Schemas.RelationshipEvent do
  @moduledoc """
  Audit trail for relationship status changes.

  Every transition is recorded so we can compute durations, funnel analysis,
  and other relationship analytics.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Relationships.Schemas.Relationship

  @valid_event_types ~w(created transition proposal proposal_accepted proposal_declined proposal_cancelled)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "relationship_events" do
    belongs_to :relationship, Relationship
    belongs_to :actor, User

    field :from_status, :string
    field :to_status, :string
    field :event_type, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:relationship_id, :actor_id, :from_status, :to_status, :event_type, :metadata])
    |> validate_required([:relationship_id, :to_status, :event_type])
    |> validate_inclusion(:event_type, @valid_event_types)
    |> foreign_key_constraint(:relationship_id)
    |> foreign_key_constraint(:actor_id)
  end

  def valid_event_types, do: @valid_event_types
end
