defmodule AniminaWeb.UserSessionController do
  use AniminaWeb, :controller

  alias Animina.Accounts
  alias Animina.ActivityLog
  alias AniminaWeb.UserAuth

  def create(conn, params) do
    create(conn, params, gettext("Welcome back!"))
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    cond do
      user = Accounts.get_user_by_email_and_password(email, password) ->
        ActivityLog.log("auth", "login_email", "#{user.display_name} logged in via email",
          actor_id: user.id,
          metadata: conn_metadata(conn)
        )

        conn
        |> put_flash(:info, info)
        |> maybe_set_sudo_return_to(user_params)
        |> UserAuth.log_in_user(user, user_params)

      deleted_user = Accounts.get_deleted_user_by_email_and_password(email, password) ->
        token =
          Phoenix.Token.sign(AniminaWeb.Endpoint, "reactivation", deleted_user.id)

        conn
        |> put_session(:reactivation_token, token)
        |> redirect(to: ~p"/users/reactivate")

      true ->
        ActivityLog.log(
          "auth",
          "login_failed",
          "Failed login attempt for #{String.slice(email, 0, 160)}",
          metadata: Map.put(conn_metadata(conn), "email", String.slice(email, 0, 160))
        )

        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, gettext("Invalid email or password"))
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, expired_tokens, security_info}} ->
        # disconnect all existing LiveViews with old sessions
        UserAuth.disconnect_sessions(expired_tokens)

        # Send password change notification email with undo/confirm links
        Accounts.UserNotifier.deliver_password_changed_notification(
          user,
          AniminaWeb.Endpoint.url() <> "/users/security/undo/#{security_info.undo_token}",
          AniminaWeb.Endpoint.url() <> "/users/security/confirm/#{security_info.confirm_token}"
        )

        conn
        |> put_session(:user_return_to, ~p"/my/settings/account/email-password")
        |> create(params, gettext("Password updated successfully!"))

      {:error, :cooldown_active} ->
        conn
        |> put_flash(
          :error,
          gettext("Cannot change password while a recent account change is being reviewed.")
        )
        |> redirect(to: ~p"/my/settings/account/email-password")
    end
  end

  def create_from_pin(conn, %{"user" => %{"user_id" => user_id} = user_params}) do
    case Accounts.get_user(user_id) do
      %Accounts.User{confirmed_at: confirmed_at} = user when not is_nil(confirmed_at) ->
        conn
        |> put_flash(:info, gettext("Email address confirmed successfully."))
        |> put_session(:user_return_to, ~p"/my/waitlist")
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, gettext("Confirmation failed. Please register again."))
        |> redirect(to: ~p"/users/register")
    end
  end

  def delete(conn, _params) do
    log_logout(conn.assigns[:current_scope], conn)

    conn
    |> put_flash(:info, gettext("Logged out successfully."))
    |> UserAuth.log_out_user()
  end

  # Set user_return_to from sudo_return_to param (validates path starts with "/")
  defp maybe_set_sudo_return_to(conn, %{"sudo_return_to" => "/" <> _ = return_to}) do
    put_session(conn, :user_return_to, return_to)
  end

  defp maybe_set_sudo_return_to(conn, _params), do: conn

  defp log_logout(%{user: %{id: id, display_name: name}}, conn) do
    ActivityLog.log("auth", "logout", "#{name} logged out",
      actor_id: id,
      metadata: conn_metadata(conn)
    )
  end

  defp log_logout(_, _conn), do: :ok

  defp conn_metadata(conn) do
    ua =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> nil
      end

    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    %{"user_agent" => ua, "ip_address" => ip}
  end
end
