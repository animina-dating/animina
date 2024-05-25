defmodule Animina.ActionPointsList do
  @moduledoc """
  Action Points List  has a list of points required for an action
  """

  @action_points_list [
    %{
      points: 100,
      action: :view_profile
    },
    %{
      points: 200,
      action: :send_message
    }
  ]
  def get_points_for_action(action, _current_user \\ nil) do
    # if the current user is there do something different
    case Enum.find(@action_points_list, fn x -> x.action == action end) do
      nil -> {:error, "Action not found"}
      action -> {:ok, action.points}
    end
  end
end
