defmodule Animina.Checks.ReadProfileCheck do
  @moduledoc """
  Policy for Ensuring An Actor Can Only read the profile of another user if they have a minimum of 20 credit points
  """
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.ActionPointsList

  def describe(_opts) do
    "Ensures An Actor Can Only read the profile of another user if they have a minimum of 20 credit points if it is their first visit and the profile is private and 10 credit points if it is the profile has liked the profile before or they are an admin"
  end

  def match?(actor, params, _opts) do
    check_if_user_can_view_profile(actor, params, params.query.arguments)
  end

  defp check_if_user_can_view_profile(actor, params, %{username: _username}) do
    case User.by_username(params.query.arguments.username) do
      {:ok, profile} ->
        if actor.username == profile.username || profile.is_private == false do
          user_can_view_profile(
            admin_user?(actor),
            profile.state
          )
        else
          user_can_view_profile(
            admin_user?(actor),
            profile.state,
            user_has_viewed_the_profile_already(profile.id, actor.id),
            user_has_liked_current_user_profile(profile, actor.id),
            actor.credit_points
          )
        end

      {:error, _} ->
        false
    end
  end

  defp check_if_user_can_view_profile(_actor, _params, _) do
    true
  end

  defp user_can_view_profile(true, :normal) do
    true
  end

  defp user_can_view_profile(true, :under_investigation) do
    true
  end

  defp user_can_view_profile(false, :under_investigation) do
    false
  end

  defp user_can_view_profile(_, _) do
    true
  end

  defp user_can_view_profile(true, :normal, _, _) do
    true
  end

  defp user_can_view_profile(true, :under_investigation_, _, _) do
    true
  end

  defp user_can_view_profile(false, :under_investigation, _, _, _) do
    false
  end

  defp user_can_view_profile(false, _, false, profile_liked, points) do
    if profile_liked do
      points >= get_points_to_view_profile_if_profile_has_liked_current_user()
    else
      points >= get_points_to_view_profile_if_profile_has_not_liked_current_user()
    end
  end

  defp user_can_view_profile(false, _, _, _, _) do
    false
  end

  defp user_has_viewed_the_profile_already(donor_id, user_id) do
    case Credit.profile_view_credits_by_donor_and_user!(donor_id, user_id) do
      [] ->
        false

      _ ->
        true
    end
  end

  defp user_has_liked_current_user_profile(user, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user.id, current_user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  def admin_user?(nil) do
    false
  end

  def admin_user?(current_user) do
    case current_user.roles do
      [] ->
        false

      roles ->
        roles
        |> Enum.map(fn x -> x.name end)
        |> Enum.any?(fn x -> x == :admin end)
    end
  end

  defp get_points_to_view_profile_if_profile_has_liked_current_user do
    case ActionPointsList.get_points_for_action(
           :first_private_profile_view_if_profile_has_liked_current_user
         ) do
      {:ok, points} ->
        points

      {:error, _} ->
        10
    end
  end

  defp get_points_to_view_profile_if_profile_has_not_liked_current_user do
    case ActionPointsList.get_points_for_action(
           :first_private_profile_view_if_profile_has_not_liked_current_user
         ) do
      {:ok, points} ->
        points

      {:error, _} ->
        20
    end
  end
end
