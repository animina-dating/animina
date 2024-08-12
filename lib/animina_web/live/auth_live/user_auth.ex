defmodule AniminaWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in liveviews
  """

  alias Animina.Accounts.Credit
  alias Animina.Accounts.Message
  alias Animina.Accounts.User
  alias AniminaWeb.Registration
  import Phoenix.Component

  use AniminaWeb, :verified_routes

  def on_mount(:live_user_optional, _params, session, socket) do
    if socket.assigns[:current_user] do
      current_user = Registration.get_current_user(session)

      add_daily_points_for_user(
        current_user,
        100,
        check_if_user_has_daily_bonus_added_for_the_day(current_user.id)
      )

      {:ok, unread_messages} = Message.unread_messages_for_user(current_user.id)

      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> assign(:unread_messages, unread_messages)
       |> assign(:number_of_unread_messages, Enum.count(unread_messages))
       |> assign(:current_user_credit_points, current_user.credit_points)}
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:unread_messages, [])
       |> assign(:number_of_unread_messages, 0)
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

    if socket.assigns[:current_user] && socket.assigns[:current_user].confirmed_at do
      current_user =
        Registration.get_current_user(session)

      add_daily_points_for_user(
        current_user,
        100,
        check_if_user_has_daily_bonus_added_for_the_day(current_user.id)
      )

      {:ok, unread_messages} = Message.unread_messages_for_user(current_user.id)

      if socket.assigns[:current_user].is_in_waitlist do
        {:halt,
         socket
         |> Phoenix.LiveView.redirect(to: "/my/too-successful")
         |> Phoenix.LiveView.put_flash(
           :info,
           "Welcome back"
         )}
      else
        {:cont,
         socket
         |> assign(:current_user, current_user)
         |> assign(:unread_messages, unread_messages)
         |> assign(:number_of_unread_messages, Enum.count(unread_messages))
         |> assign(:current_user_credit_points, current_user.credit_points)}
      end
    else
      {:halt,
       socket
       |> Phoenix.LiveView.redirect(to: "/#{path}")
       |> Phoenix.LiveView.put_flash(
         :error,
         "You need to be authenticated  confirmed , and have an active account to access this page . If you are already signed up , check your email for the confirmation link"
       )}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt,
       Phoenix.LiveView.redirect(socket, to: ~p"/#{socket.assigns[:current_user].username}")}
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:unread_messages, [])
       |> assign(:number_of_unread_messages, 0)
       |> assign(:current_user, nil)}
    end
  end

  def on_mount(:live_user_home_optional, _params, _session, socket) do
    if socket.assigns[:current_user] && socket.assigns[:current_user].confirmed_at do
      if socket.assigns[:current_user].is_in_waitlist do
        {:halt, Phoenix.LiveView.redirect(socket, to: "/my/too-successful")}
      else
        {:halt, Phoenix.LiveView.redirect(socket, to: "/my/dashboard")}
      end
    else
      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:unread_messages, [])
       |> assign(:number_of_unread_messages, 0)
       |> assign(:current_user, nil)}
    end
  end

  def on_mount(:live_admin_required, _params, session, socket) do
    if socket.assigns[:current_user] && user_is_admin(socket.assigns[:current_user]) do
      current_user = Registration.get_current_user(session)

      add_daily_points_for_user(
        current_user,
        100,
        check_if_user_has_daily_bonus_added_for_the_day(current_user.id)
      )

      {:ok, unread_messages} = Message.unread_messages_for_user(current_user.id)

      {:cont,
       socket
       |> assign(:current_user, current_user)
       |> assign(:unread_messages, unread_messages)
       |> assign(:number_of_unread_messages, Enum.count(unread_messages))
       |> assign(:current_user_credit_points, current_user.credit_points)}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(
         :error,
         "You need to be authenticated as an admin and confirmed to access this page . If you are already signed up , check your email for the confirmation link"
       )
       |> Phoenix.LiveView.redirect(to: "/sign-in")}
    end
  end

  def on_mount(:live_user_required_for_validation, _params, session, socket) do
    if socket.assigns[:current_user] && socket.assigns[:current_user].confirmed_at == nil do
      current_user = Registration.get_current_user(session)

      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:unread_messages, [])
       |> assign(:number_of_unread_messages, 0)
       |> assign(:current_user, current_user)}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.redirect(to: "/sign-in")}
    end
  end

  def on_mount(:live_user_required_for_too_successful, _params, session, socket) do
    if socket.assigns[:current_user] && socket.assigns[:current_user].confirmed_at != nil &&
         socket.assigns[:current_user].is_in_waitlist do
      current_user = Registration.get_current_user(session)

      {:cont,
       socket
       |> assign(:current_user_credit_points, 0)
       |> assign(:unread_messages, [])
       |> assign(:number_of_unread_messages, 0)
       |> assign(:current_user, current_user)}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.redirect(to: "/sign-in")}
    end
  end

  defp user_is_admin(user) do
    user = User.by_id!(user.id)
    Enum.any?(user.roles, fn role -> role.name == :admin end)
  end

  # in this case the user does not have a daily bonus added for the day , so we add one
  defp add_daily_points_for_user(user, points, nil) do
    Credit.create(%{
      user_id: user.id,
      points: points,
      subject: "Daily Bonus"
    })

    user = update_streak_depending_on_whether_used_the_system_a_day_before(user)

    # we then check if a user has been using has a streak of 10 days
    # we add 150 extra points so that they can have a total of 250 points

    if is_multiple_of_ten(user.streak) do
      Credit.create(%{
        user_id: user.id,
        points: 150,
        subject: "Daily Bonus"
      })
    end
  end

  defp add_daily_points_for_user(_user, _points, _) do
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

  def is_multiple_of_ten(streak) when is_integer(streak) do
    rem(streak, 10) == 0
  end

  def current_day do
    Timex.now()
  end

  def previous_day do
    Timex.shift(Timex.now(), days: -1)
  end

  def daily_bonus_credits_for_a_user(user_id) do
    {:ok, credits} = Credit.read()

    credits
    |> Enum.filter(fn credit ->
      credit.user_id == user_id and credit.subject == "Daily Bonus"
    end)
  end

  def update_streak_depending_on_whether_used_the_system_a_day_before(user) do
    daily_bonus_credits =
      daily_bonus_credits_for_a_user(user.id)
      |> Enum.filter(fn credit ->
        format_date(credit.created_at) == format_date(previous_day())
      end)

    # if a user used the system before , we add the streak and if they did not , we reset it to 1

    if Enum.count(daily_bonus_credits) > 0 do
      {:ok, user} = User.update(user, %{streak: user.streak + 1})
      user
    else
      {:ok, user} = User.update(user, %{streak: 1})
      user
    end
  end
end
