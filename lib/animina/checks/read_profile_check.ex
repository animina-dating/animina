defmodule Animina.Checks.ReadProfileCheck do
  @moduledoc """
  Policy for Ensuring An Actor Can Only read the profile of another user if they have a minimum of 20 credit points
  """
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.User

  def describe(_opts) do
    "Ensures An Actor Can Only read the profile of another user if they have a minimum of 20 credit points"
  end


  def match?(actor, params, _opts) do
    IO.inspect params

    profile = User.by_username!(params.query.arguments.username)



    if actor.username == profile.username do
      true
    else
      if profile.is_private && actor.credit_points < 20 do
        false
      else
        true
      end
    end
  end
end
