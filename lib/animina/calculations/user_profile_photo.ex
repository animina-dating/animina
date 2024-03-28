defmodule Animina.Calculations.UserProfilePhoto do
  @moduledoc """
  This is a module for getting a user's profile photo.
  """

  alias Animina.Accounts
  use Ash.Calculation

  def calculate(records, opts, _) do
    Enum.map(records, fn record -> get_profile_photo(Map.get(record, opts[:field])) end)
  end

  defp get_profile_photo(user_id) do
    Accounts.Photo
    |> Ash.Query.for_read(:user_profile_photo, %{user_id: user_id})
    |> Accounts.read!(page: [limit: 1])
    |> then(&Enum.at(&1.results, 0, nil))
  end
end
