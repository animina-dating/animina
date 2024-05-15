defmodule Animina.Checks.ReadUserRoleCheck do
  @moduledoc """
  Policy for The Reading of User Roles
  """
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Read User Role Check"
  end

  def match?(_actor, _params, _opts) do
    true
  end
end
