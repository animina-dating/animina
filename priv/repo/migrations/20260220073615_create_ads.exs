defmodule Animina.Repo.Migrations.CreateAds do
  use Ecto.Migration

  def change do
    create table(:ads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :number, :integer, null: false
      add :url, :string, null: false
      add :description, :text
      add :starts_on, :date
      add :ends_on, :date
      add :qr_code_path, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ads, [:number])
    create unique_index(:ads, [:url])

    create constraint(:ads, :starts_on_before_ends_on,
             check: "starts_on IS NULL OR ends_on IS NULL OR starts_on <= ends_on"
           )
  end
end
