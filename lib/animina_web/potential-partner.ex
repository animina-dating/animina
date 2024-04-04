defmodule AniminaWeb.PotentialPartner do
  @moduledoc """
  Functions for querying potential partners.
  """

  alias Animina.Accounts
  alias Animina.Accounts.User

  require Ash.Query

  @doc """
  Gets random users by the given limit.
  """
  def get_random_users(limit \\ 10) do
    User
    |> Ash.Query.for_read(:random_users)
    |> Ash.Query.limit(limit)
    |> Accounts.read!()
  end
end
