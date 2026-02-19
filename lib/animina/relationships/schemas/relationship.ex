defmodule Animina.Relationships.Schemas.Relationship do
  @moduledoc """
  Schema for the relationship between two users.

  `user_a_id` is always the lexicographically smaller UUID (canonical ordering).
  This ensures exactly one row per pair and simplifies lookups.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.TimeMachine

  @valid_statuses ~w(chatting dating couple married separated divorced ex friend blocked ended)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "relationships" do
    belongs_to :user_a, User
    belongs_to :user_b, User

    field :status, :string, default: "chatting"
    field :status_changed_at, :utc_datetime
    field :status_changed_by, :binary_id

    field :pending_status, :string
    field :pending_proposed_by, :binary_id
    field :pending_proposed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:user_a_id, :user_b_id, :status, :status_changed_at, :status_changed_by])
    |> validate_required([:user_a_id, :user_b_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_canonical_ordering()
    |> foreign_key_constraint(:user_a_id)
    |> foreign_key_constraint(:user_b_id)
    |> unique_constraint([:user_a_id, :user_b_id])
  end

  def transition_changeset(relationship, new_status, actor_id) do
    relationship
    |> change(
      status: new_status,
      status_changed_at: TimeMachine.utc_now(:second),
      status_changed_by: actor_id,
      pending_status: nil,
      pending_proposed_by: nil,
      pending_proposed_at: nil
    )
    |> validate_inclusion(:status, @valid_statuses)
  end

  def proposal_changeset(relationship, proposed_status, proposer_id) do
    change(relationship,
      pending_status: proposed_status,
      pending_proposed_by: proposer_id,
      pending_proposed_at: TimeMachine.utc_now(:second)
    )
  end

  def clear_proposal_changeset(relationship) do
    change(relationship,
      pending_status: nil,
      pending_proposed_by: nil,
      pending_proposed_at: nil
    )
  end

  def valid_statuses, do: @valid_statuses

  defp validate_canonical_ordering(changeset) do
    user_a_id = get_field(changeset, :user_a_id)
    user_b_id = get_field(changeset, :user_b_id)

    if user_a_id && user_b_id && user_a_id >= user_b_id do
      add_error(changeset, :user_a_id, "must be lexicographically smaller than user_b_id")
    else
      changeset
    end
  end
end
