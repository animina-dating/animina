defmodule Animina.PointsPriceList do
  @moduledoc """
  Points price list that has a list of points required for an action and their corresponding price.
  """

  @points_price_list [
    %{
      points: 100,
      price: 10,
      action: :view_profile
    },
    %{
      points: 200,
      price: 20,
      action: :send_message
    },

  ]


  def get_price_for_action(action) do
    case Enum.find(@points_price_list, fn x -> x.action == action end) do
      nil -> {:error, "Action not found"}
      action -> {:ok, action.price}
    end
  end

end
