defmodule Animina.Traits.Flag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "trait_flags" do
    field :name, :string
    field :emoji, :string
    field :position, :integer

    belongs_to :category, Animina.Traits.Category
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  def changeset(flag, attrs) do
    flag
    |> cast(attrs, [:name, :emoji, :category_id, :parent_id, :position])
    |> validate_required([:name, :category_id, :position])
    |> foreign_key_constraint(:category_id)
    |> foreign_key_constraint(:parent_id)
    |> unique_constraint([:category_id, :name])
  end
end
