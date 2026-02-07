defmodule Animina.Discovery.Schemas.DailyDiscoverySet do
  @moduledoc """
  Schema for storing daily discovery sets.

  Each user gets a fixed set of suggestions per day (Berlin date).
  The set is generated once and persisted so reloads return the same profiles.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "daily_discovery_sets" do
    belongs_to :user, User
    belongs_to :candidate, User

    field :set_date, :date
    field :is_wildcard, :boolean, default: false
    field :position, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(set, attrs) do
    set
    |> cast(attrs, [:user_id, :candidate_id, :set_date, :is_wildcard, :position])
    |> validate_required([:user_id, :candidate_id, :set_date, :position])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:candidate_id)
    |> unique_constraint([:user_id, :set_date, :candidate_id])
  end
end
