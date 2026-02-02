defmodule Animina.Traits.UserFlag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @valid_colors ~w(white green red)
  @valid_intensities ~w(hard soft)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_flags" do
    field :color, :string
    field :intensity, :string, default: "hard"
    field :position, :integer
    field :inherited, :boolean, default: false

    belongs_to :user, Animina.Accounts.User
    belongs_to :flag, Animina.Traits.Flag
    belongs_to :source_flag, Animina.Traits.Flag

    timestamps(type: :utc_datetime)
  end

  def changeset(user_flag, attrs) do
    user_flag
    |> cast(attrs, [
      :user_id,
      :flag_id,
      :color,
      :intensity,
      :position,
      :inherited,
      :source_flag_id
    ])
    |> validate_required([:user_id, :flag_id, :color, :intensity, :position])
    |> validate_inclusion(:color, @valid_colors)
    |> validate_inclusion(:intensity, @valid_intensities)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:flag_id)
    |> unique_constraint([:user_id, :flag_id, :color])
    |> check_constraint(:color, name: :valid_color)
    |> check_constraint(:intensity, name: :valid_intensity)
  end
end
