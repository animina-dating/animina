defmodule AniminaWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  alias AniminaWeb.Registration
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Points
  import Phoenix.Component

  use AniminaWeb, :verified_routes

  def on_mount(:live_user_optional, _params, session, socket) do
    if socket.assigns[:current_user] do
      current_user = Registration.get_current_user(session)

      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> assign(:current_user_credit_points, current_user.credit_points)}
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, session, socket) do
    path =
      case Map.get(socket.private.connect_info, :request_path, nil) do
        nil ->
          "sign-in"

        path ->
          case Map.get(socket.private.connect_info, :query_string, nil) do
            nil ->
              "sign-in?redirect_to=" <> path

            "" ->
              "sign-in?redirect_to=" <> path

            query_string ->
              "sign-in?redirect_to=" <> path <> "?" <> query_string
          end
      end

    if socket.assigns[:current_user] do
      current_user = Registration.get_current_user(session)

      add_daily_points_for_user(
        current_user,
        100,
        check_if_user_has_daily_bonus_added_for_the_day(current_user.id)
      )

      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> assign(:current_user_credit_points, current_user.credit_points)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/#{path}")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:current_user, nil)}
    end
  end

  def check_if_user_has_daily_bonus_added_for_the_day(user_id) do
    {:ok, credits} = Credit.read()

    credits
    |> Enum.filter(fn credit ->
      credit.user_id == user_id and
        format_date(credit.created_at) == format_date(DateTime.utc_now()) and
        credit.subject == "Daily Bonus"
    end)
    |> List.first()
  end

  defp format_date(date) do
    {:ok, date} = Timex.format(date, "{YYYY}-{0M}-{0D}")
    date
  end

  # in this case the user does not have a daily bonus added for the day , so we add one
  defp add_daily_points_for_user(user, points, nil) do
    Credit.create(%{
      user_id: user.id,
      points: points,
      subject: "Daily Bonus"
    })

    # we then check if a user has been using the system for 10 days straight if so ,
    # we add 150 extra points so that they can have a total of 250 points

    if Points.has_daily_bonus_for_the_past_ten_days(
         daily_bonus_credits_for_a_user(user.id),
         current_day()
       ) do
      Credit.create(%{
        user_id: user.id,
        points: 150,
        subject: "Daily Bonus"
      })
    end
  end

  defp add_daily_points_for_user(_user, _points, _) do
  end

  def current_day do
    Timex.now()
  end

  def daily_bonus_credits_for_a_user(user_id) do
    {:ok, credits} = Credit.read()

    credits
    |> Enum.filter(fn credit ->
      credit.user_id == user_id and credit.subject == "Daily Bonus"
    end)
  end
end
