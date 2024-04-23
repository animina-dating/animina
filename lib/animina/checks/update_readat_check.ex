defmodule Animina.Checks.UpdateReadAtCheck do
  @moduledoc """
  Policy for The Update Message Action That updates the read_at field
  """
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Ensures an actor can only update messages that they are the  receiver of"
  end

  def match?(actor, params, _opts) do
    if actor.id == params.changeset.data.receiver_id do
      true
    else
      false
    end
  end
end
