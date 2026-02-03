defmodule Animina.Repo.Migrations.CreateFunWithFlagsToggles do
  use Ecto.Migration

  def change do
    create table(:fun_with_flags_toggles, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :flag_name, :string, null: false
      add :gate_type, :string, null: false
      add :target, :string
      add :enabled, :boolean, null: false
    end

    create index(:fun_with_flags_toggles, [:flag_name])
    create index(:fun_with_flags_toggles, [:flag_name, :gate_type, :target], unique: true)
  end
end
