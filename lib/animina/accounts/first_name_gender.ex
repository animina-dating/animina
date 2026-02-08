defmodule Animina.Accounts.FirstNameGender do
  @moduledoc """
  Caches the guessed gender for a given first name.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "first_name_genders" do
    field :first_name, :string
    field :gender, :string
    field :needs_human_review, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(first_name_gender, attrs) do
    first_name_gender
    |> cast(attrs, [:first_name, :gender, :needs_human_review])
    |> validate_required([:first_name, :gender])
    |> validate_inclusion(:gender, ["male", "female"])
    |> downcase_first_name()
    |> unique_constraint(:first_name)
  end

  defp downcase_first_name(changeset) do
    case get_change(changeset, :first_name) do
      nil -> changeset
      name -> put_change(changeset, :first_name, String.downcase(name))
    end
  end
end
