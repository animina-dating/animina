defmodule Animina.Traits.Category do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @valid_selection_modes ~w(multi single single_white)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "trait_categories" do
    field :name, :string
    field :selection_mode, :string, default: "multi"
    field :sensitive, :boolean, default: false
    field :exclusive_hard, :boolean, default: false
    field :core, :boolean, default: false
    field :picker_group, :string
    field :position, :integer

    has_many :flags, Animina.Traits.Flag, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [
      :name,
      :selection_mode,
      :sensitive,
      :exclusive_hard,
      :core,
      :picker_group,
      :position
    ])
    |> validate_required([:name, :selection_mode, :position])
    |> validate_inclusion(:selection_mode, @valid_selection_modes)
    |> unique_constraint(:name)
    |> check_constraint(:selection_mode, name: :valid_selection_mode)
  end
end
