defmodule Animina.Discovery.Schemas.SuggestionView do
  @moduledoc """
  Schema for tracking when a user was shown another user as a suggestion.
  Used to implement the cooldown period before a user can reappear in suggestions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @list_types ~w(combined safe attracted)

  schema "user_suggestion_views" do
    belongs_to :viewer, User
    belongs_to :suggested, User

    field :list_type, :string
    field :shown_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(suggestion_view, attrs) do
    suggestion_view
    |> cast(attrs, [:viewer_id, :suggested_id, :list_type, :shown_at])
    |> validate_required([:viewer_id, :suggested_id, :list_type, :shown_at])
    |> validate_inclusion(:list_type, @list_types)
    |> foreign_key_constraint(:viewer_id)
    |> foreign_key_constraint(:suggested_id)
    |> unique_constraint([:viewer_id, :suggested_id, :list_type])
  end

  def list_types, do: @list_types
end
