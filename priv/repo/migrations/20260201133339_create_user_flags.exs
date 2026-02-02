defmodule Animina.Repo.Migrations.CreateUserFlags do
  use Ecto.Migration

  def change do
    create table(:user_flags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :color, :string, null: false
      add :intensity, :string, null: false, default: "hard"
      add :position, :integer, null: false
      add :inherited, :boolean, null: false, default: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :flag_id, references(:trait_flags, type: :binary_id, on_delete: :delete_all),
        null: false

      add :source_flag_id, references(:trait_flags, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_flags, [:user_id, :flag_id])
    create index(:user_flags, [:user_id])
    create index(:user_flags, [:flag_id])
    create index(:user_flags, [:color])

    create constraint(:user_flags, :valid_color, check: "color IN ('white', 'green', 'red')")

    create constraint(:user_flags, :valid_intensity, check: "intensity IN ('hard', 'soft')")
  end
end
