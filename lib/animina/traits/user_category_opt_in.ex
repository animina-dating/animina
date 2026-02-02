defmodule Animina.Traits.UserCategoryOptIn do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_category_opt_ins" do
    belongs_to :user, Animina.Accounts.User
    belongs_to :category, Animina.Traits.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(opt_in, attrs) do
    opt_in
    |> cast(attrs, [:user_id, :category_id])
    |> validate_required([:user_id, :category_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:user_id, :category_id])
  end
end
