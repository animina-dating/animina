defmodule Animina.Accounts.UserLocation do
  @moduledoc """
  Schema for user location preferences, supporting up to 4 locations per user.
  """

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
    |> validate_zip_code_exists()
    |> validate_inclusion(:position, 1..4, message: "must be between 1 and 4")
    |> unique_constraint([:user_id, :position])
    |> unique_constraint([:user_id, :zip_code])
  end

  defp validate_zip_code_exists(changeset) do
    validate_change(changeset, :zip_code, fn :zip_code, zip_code ->
      if Animina.GeoData.get_city_by_zip_code(zip_code) do
        []
      else
        [zip_code: "zip code not found"]
      end
    end)
  end
end
