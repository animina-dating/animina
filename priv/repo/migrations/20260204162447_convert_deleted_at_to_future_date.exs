defmodule Animina.Repo.Migrations.ConvertDeletedAtToFutureDate do
  use Ecto.Migration

  @doc """
  Converts existing deleted_at values from "deletion timestamp" semantics
  to "hard delete date" semantics.

  Before: deleted_at = when the user deleted their account
  After: deleted_at = when the account will be permanently deleted (28 days after soft delete)

  This migration adds 28 days to existing deleted_at values so that:
  - Users who deleted their account recently still have time to reactivate
  - The new purge logic (delete where deleted_at < now) will work correctly
  """
  def up do
    # Convert existing deleted_at timestamps to future dates
    # by adding 28 days (the default grace period)
    execute """
    UPDATE users
    SET deleted_at = deleted_at + INTERVAL '28 days'
    WHERE deleted_at IS NOT NULL
    """
  end

  def down do
    # Revert by subtracting 28 days
    execute """
    UPDATE users
    SET deleted_at = deleted_at - INTERVAL '28 days'
    WHERE deleted_at IS NOT NULL
    """
  end
end
