defmodule Animina.Calculations.PostUrl do
  @moduledoc """
  This is a module for calculating the post url using slug, user and the time the post was created.
  """

  use Ash.Calculation

  def calculate(records, _opts, _) do
    Enum.map(records, fn record -> calculate_post_url(record) end)
  end

  def calculate_post_url(record) do
    # get the post creation day, month and year
    date = Map.get(record, :created_at)
    year = date |> Calendar.strftime("%Y")
    month = date |> Calendar.strftime("%m")
    day = date |> Calendar.strftime("%d")

    # get the post user's username
    username =
      Map.get(record, :user)
      |> Map.get(:username)
      |> Ash.CiString.value()

    # get the post title slug
    title_slug = Map.get(record, :slug)

    "/" <> username <> "/" <> year <> "/" <> month <> "/" <> day <> "/" <> title_slug
  end
end
