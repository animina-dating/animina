defmodule AniminaWeb.AuthController do
  use AniminaWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Animina.Accounts.Reaction
  alias Animina.Accounts.Token
  alias Animina.Accounts.User
  alias Animina.Narratives.Story
  alias AshAuthentication.TokenResource

  def success(conn, _activity, user, _token) do
    return_to =
      case Map.get(conn.query_params, "redirect_to") do
        nil ->
          get_session(conn, :return_to) || redirect_url(user)

        path ->
          path
      end

    get_actions_to_perform(conn.query_params, user)

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  defp get_actions_to_perform(%{"action" => action, "user" => username}, actor) do
    case User.by_username(username) do
      {:ok, user} ->
        if action == "like" do
          Reaction.like(
            %{
              sender_id: actor.id,
              receiver_id: user.id
            },
            actor: actor
          )
        end

      _ ->
        :error
    end
  end

  defp get_actions_to_perform(_, _user_id) do
  end

  def failure(
        conn,
        {:password, :sign_in},
        %AshAuthentication.Errors.AuthenticationFailed{} = reason
      ) do
    conn
    |> assign(:errors, reason)
    |> put_flash(
      :error,
      gettext("Username or password is incorrect")
    )
    |> redirect(to: "/sign-in")
  end

  def failure(
        conn,
        {:confirm_new_user, :confirm},
        _reason
      ) do
    conn
    |> put_flash(
      :error,
      gettext("Invalid Email Confirmation Link")
    )
    |> redirect(to: "/")
  end

  def failure(
        conn,
        {:password, :register},
        reason
      ) do
    conn
    |> assign(:errors, reason)
    |> put_flash(
      :error,
      gettext("Something went wrong. Try again.") <>
        " " <>
        Enum.map_join(reason.errors, "\n", fn x ->
          (to_string(x.field) |> String.capitalize()) <> " " <> x.message
        end)
    )
    |> redirect(to: "/")
  end

  def sign_in(conn, params) do
    case User.custom_sign_in(%{
           "username_or_email" => params["user"]["username_or_email"],
           "password" => params["user"]["password"]
         }) do
      {:ok, user} ->
        return_to =
          case Map.get(conn.query_params, "redirect_to") do
            nil ->
              get_session(conn, :return_to) || redirect_url(user)

            path ->
              path
          end

        get_actions_to_perform(conn.query_params, user)

        conn
        |> delete_session(:return_to)
        |> store_in_session(user)
        |> assign(:current_user, user)
        |> redirect(to: return_to)

      {:error, body} ->
        message = (body.errors |> List.first()).caused_by.message

        conn
        |> put_flash(
          :error,
          message
        )
        |> redirect(to: "/sign-in")
    end
  end

  def sign_out(conn, %{"auto_log_out" => state}) do
    return_to = get_session(conn, :return_to) || ~p"/sign-in"

    token = Plug.Conn.get_session(conn, "user_token")

    if token do
      Token
      |> TokenResource.Actions.get_token(%{"token" => token})
      |> case do
        {:ok, [token]} ->
          Token.destroy!(token, authorize?: false)

        _ ->
          :ok
      end
    end

    conn
    |> clear_session()
    |> put_flash(
      :error,
      get_auto_logout_text(state)
    )
    |> redirect(to: return_to)
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/sign-in"

    token = Plug.Conn.get_session(conn, "user_token")

    if token do
      Token
      |> TokenResource.Actions.get_token(%{"token" => token})
      |> case do
        {:ok, [token]} ->
          Token.destroy!(token, authorize?: false)

        _ ->
          :ok
      end
    end

    conn
    |> clear_session()
    |> put_flash(:info, gettext("You have signed out successfully"))
    |> redirect(to: return_to)
  end

  defp get_auto_logout_text(state) do
    case state do
      "under_investigation" ->
        gettext(
          "Your account is currently under investigation. Please try again to login in 24 hours."
        )

      "banned" ->
        gettext("Your account has been banned. Please contact support for more information.")

      "archived" ->
        gettext("Your account has been archived")

      _ ->
        gettext("Your account has been banned. Please contact support for more information.")
    end
  end

  defp redirect_url(user) do
    if user.confirmed_at == nil do
      "/my/email-validation"
    else
      if user_has_an_about_me_story?(user) do
        "/my/dashboard"
      else
        get_last_registration_page_visited(user.last_registration_page_visited)
      end
    end
  end

  defp user_has_an_about_me_story?(user) do
    case get_stories_for_a_user(user) do
      [] ->
        false

      stories ->
        Enum.any?(stories, fn story ->
          story.headline.subject == "About me"
        end)
    end
  end

  defp get_last_registration_page_visited(nil) do
    "/my/potential-partner"
  end

  defp get_last_registration_page_visited(last_registration_page_visited) do
    last_registration_page_visited
  end

  defp get_stories_for_a_user(user) do
    {:ok, stories} = Story.by_user_id(user.id)
    stories
  end
end
