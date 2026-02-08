defmodule Animina.Repo.Migrations.CreateFirstNameGenders do
  use Ecto.Migration

  def change do
    create table(:first_name_genders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :first_name, :string, null: false
      add :gender, :string, null: false
      add :needs_human_review, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:first_name_genders, [:first_name])
  end
end
