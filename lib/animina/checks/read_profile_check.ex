defmodule Animina.Checks.ReadProfileCheck do
  @moduledoc """
  Policy for Ensuring An Actor Can Only read the profile of another user if they have a minimum of 20 credit points
  """
  use Ash.Policy.SimpleCheck
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User

  def describe(_opts) do
    "Ensures An Actor Can Only read the profile of another user if they have a minimum of 20 credit points if it is their first visit and the profile is private and 10 credit points if it is the profile has liked the profile before"
  end

  def match?(actor, params, _opts) do
    case IO.inspect User.by_username(params.query.arguments.username) do


      {:ok, profile} ->
        IO.inspect("here")
        if actor.username == profile.username || profile.is_private == false do
          true
        else
          user_can_view_profile(
            user_has_viewed_the_profile_already(profile.id, actor.id),
            user_has_liked_current_user_profile(profile, actor.id),
            actor.credit_points
          )
        end

      {:error, _} ->
        false
    end
  end

  defp user_can_view_profile(true, true, _) do
    true
  end

  defp user_can_view_profile(false, true, points) when points >= 10 do
    true
  end

  defp user_can_view_profile(false, false, points) when points >= 20 do
    true
  end

  defp user_can_view_profile(_, _, _) do
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
end
