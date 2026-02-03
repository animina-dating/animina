defmodule Animina.Repo.Migrations.SimplifyOllamaStates do
  use Ecto.Migration

  def up do
    # Update pending Ollama states to unified pending_ollama
    execute """
    UPDATE photos
    SET state = 'pending_ollama',
        ollama_check_type = NULL
    WHERE state IN ('pending_ollama_nsfw', 'pending_ollama_face', 'pending_ollama_combined')
    """

    # Update checking Ollama states to unified ollama_checking
    execute """
    UPDATE photos
    SET state = 'ollama_checking',
        ollama_check_type = NULL
    WHERE state IN ('nsfw_checking_ollama', 'face_checking_ollama', 'combined_checking_ollama')
    """

    # Clear ollama_check_type for photos in needs_manual_review
    execute """
    UPDATE photos
    SET ollama_check_type = NULL
    WHERE state = 'needs_manual_review'
    """
  end

  def down do
    # Cannot reliably reverse this migration since we don't know
    # which original state each photo was in.
    # Photos that were migrated will stay in the new unified states.
    :ok
  end
end
