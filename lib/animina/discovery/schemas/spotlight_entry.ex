defmodule Animina.Discovery.Schemas.SpotlightEntry do
  @moduledoc """
  Schema for daily spotlight entries.

  Each entry represents one candidate shown to a viewer on a given day.
  Entries are seeded once per day (Berlin midnight reset) and remain stable
  for the full day.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "spotlight_entries" do
    belongs_to :user, User
    belongs_to :shown_user, User
    field :shown_on, :date
    field :is_wildcard, :boolean, default: false
    field :cycle_number, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:user_id, :shown_user_id, :shown_on, :is_wildcard, :cycle_number])
    |> validate_required([:user_id, :shown_user_id, :shown_on])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:shown_user_id)
    |> unique_constraint([:user_id, :shown_user_id, :shown_on])
  end
end
