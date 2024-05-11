defmodule Animina.Checks.ReadUserRoleCheck do
  @moduledoc """
  Policy for The Reading of User Roles
  """
  use Ash.Policy.SimpleCheck

  def match?(actor, params, _opts) do
    true
  end
end
