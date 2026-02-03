defmodule Animina.Repo.Migrations.AddOllamaRetryFieldsToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      # Number of Ollama retry attempts (0 = not in retry queue)
      add :ollama_retry_count, :integer, default: 0, null: false

      # When to attempt next retry (null = not scheduled)
      add :ollama_retry_at, :utc_datetime

      # Which check is pending: "nsfw" or "face"
      add :ollama_check_type, :string

      # Store original Bumblebee score for context
      add :ollama_bumblebee_score, :float
    end

    # Index for efficient lookup of photos due for retry
    create index(:photos, [:ollama_retry_at],
             where: "ollama_retry_at IS NOT NULL",
             name: :photos_ollama_retry_at_pending_index
           )

    # Index for listing photos by state (useful for admin page)
    create index(:photos, [:state],
             where:
               "state IN ('pending_ollama_nsfw', 'pending_ollama_face', 'needs_manual_review')",
             name: :photos_ollama_pending_states_index
           )
  end
end
