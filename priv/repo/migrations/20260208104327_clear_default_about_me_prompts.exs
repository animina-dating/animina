defmodule Animina.Repo.Migrations.ClearDefaultAboutMePrompts do
  use Ecto.Migration

  def up do
    execute """
    UPDATE moodboard_stories
    SET content = '', updated_at = NOW()
    WHERE moodboard_item_id IN (
      SELECT id FROM moodboard_items WHERE pinned = true
    )
    AND content IN ('Tell us about yourself...', 'Erzähl uns etwas über dich...')
    """
  end

  def down do
    # Cannot reliably restore original language-specific defaults
    :ok
  end
end
