defmodule Animina.Repo.Migrations.CreateWingmanFeedbacks do
  use Ecto.Migration

  def change do
    create table(:wingman_feedbacks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :conversation_id,
          references(:conversations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :suggestion_index, :integer, null: false
      add :suggestion_text, :text, null: false
      add :suggestion_hook, :text
      add :value, :integer, null: false
      add :wingman_style, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wingman_feedbacks, [:user_id, :conversation_id, :suggestion_index])
    create index(:wingman_feedbacks, [:user_id, :inserted_at])
    create constraint(:wingman_feedbacks, :valid_feedback_value, check: "value IN (-1, 1)")

    create constraint(:wingman_feedbacks, :valid_suggestion_index,
             check: "suggestion_index IN (0, 1)"
           )
  end
end
