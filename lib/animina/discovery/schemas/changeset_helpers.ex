defmodule Animina.Discovery.Schemas.ChangesetHelpers do
  @moduledoc """
  Shared changeset validation helpers for discovery schemas.
  """

  import Ecto.Changeset

  def validate_different_users(changeset, field_a, field_b) do
    a = get_field(changeset, field_a)
    b = get_field(changeset, field_b)

    if a && b && a == b do
      add_error(changeset, field_b, "must be different from #{field_a}")
    else
      changeset
    end
  end
end
