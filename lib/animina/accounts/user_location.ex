defmodule Animina.Accounts.UserLocation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_locations" do
    field :zip_code, :string
    field :position, :integer

    belongs_to :user, Animina.Accounts.User
    belongs_to :country, Animina.GeoData.Country

    timestamps(type: :utc_datetime)
  end

  def changeset(user_location, attrs) do
    user_location
    |> cast(attrs, [:user_id, :country_id, :zip_code, :position])
    |> validate_required([:user_id, :country_id, :zip_code, :position])
    |> validate_format(:zip_code, ~r/^\d{5}$/, message: "must be 5 digits")
    |> validate_inclusion(:position, 1..4, message: "must be between 1 and 4")
    |> unique_constraint([:user_id, :position])
    |> unique_constraint([:user_id, :zip_code])
  end
end
