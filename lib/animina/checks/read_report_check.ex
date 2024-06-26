defmodule Animina.Checks.ReadReportCheck do
  @moduledoc """
  Policy for The Read Action for a Report
  """
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Ensures an actor can only read reports if they are admins"
  end

  def match?(actor, _params, _opts) do
    check_if_actor_is_admin(actor.roles)
  end

  defp check_if_actor_is_admin(roles) do
    Enum.any?(roles, fn role -> role.name == :admin end)
  end
end
