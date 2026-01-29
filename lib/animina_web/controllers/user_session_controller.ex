defmodule AniminaWeb.UserSessionController do
  use AniminaWeb, :controller

  alias Animina.Accounts
  alias AniminaWeb.UserAuth

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create_from_pin(conn, %{"user" => %{"user_id" => user_id} = user_params}) do
    case Accounts.get_user(user_id) do
      %Accounts.User{confirmed_at: confirmed_at} = user when not is_nil(confirmed_at) ->
        conn
        |> put_flash(:info, "E-Mail-Adresse erfolgreich bestätigt.")
        |> put_session(:user_return_to, ~p"/users/waitlist")
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "Bestätigung fehlgeschlagen. Bitte registriere dich erneut.")
        |> redirect(to: ~p"/users/register")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
