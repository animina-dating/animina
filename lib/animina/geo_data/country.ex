defmodule Animina.GeoData.Country do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "countries" do
    field :name, :string
    field :code, :string

    has_many :cities, Animina.GeoData.City

    timestamps()
  end

  @required_fields ~w(name code)a

  def changeset(country, attrs) do
    country
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_length(:code, is: 2)
    |> update_change(:code, &String.upcase/1)
    |> unique_constraint(:code)
  end
end
