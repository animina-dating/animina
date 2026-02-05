defmodule Animina.Traits.UserWhiteFlagCategoryPublish do
  @moduledoc """
  Schema for tracking which white flag categories a user wants to publish on their moodboard.

  Presence in this table means the category's white flags are published.
  Absence means the category's white flags are private (default).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_white_flag_category_publish" do
    belongs_to :user, Animina.Accounts.User
    belongs_to :category, Animina.Traits.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(publish, attrs) do
    publish
    |> cast(attrs, [:user_id, :category_id])
    |> validate_required([:user_id, :category_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:user_id, :category_id])
  end
end
