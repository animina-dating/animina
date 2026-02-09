defmodule AniminaWeb.SecurityEventController do
  use AniminaWeb, :controller

  alias Animina.Accounts

  def undo(conn, %{"token" => token}) do
    case Accounts.undo_security_event(token) do
      {:ok, _event} ->
        conn
        |> put_flash(
          :info,
          gettext(
            "The account change has been undone. All sessions have been logged out for security. Please log in again."
          )
        )
        |> redirect(to: ~p"/users/log-in")

      {:error, _reason} ->
        conn
        |> put_flash(
          :error,
          gettext("This undo link is invalid, has expired, or has already been used.")
        )
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_security_event(token) do
      {:ok, _event} ->
        conn
        |> put_flash(
          :info,
          gettext("Account change confirmed. The security cooldown has been cleared.")
        )
        |> redirect(to: ~p"/users/log-in")

      {:error, _reason} ->
        conn
        |> put_flash(
          :error,
          gettext("This confirmation link is invalid, has expired, or has already been used.")
        )
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
