defmodule AniminaWeb.RoleController do
  use AniminaWeb, :controller

  alias Animina.Accounts
  use Gettext, backend: AniminaWeb.Gettext

  def switch(conn, %{"role" => role}) do
    user = conn.assigns.current_scope.user
    roles = Accounts.get_user_roles(user)

    if role in roles do
      conn
      |> put_session(:current_role, role)
      |> redirect_back()
    else
      conn
      |> put_flash(:error, gettext("You do not have that role."))
      |> redirect_back()
    end
  end

  def switch(conn, _params) do
    redirect_back(conn)
  end

  defp redirect_back(conn) do
    path =
      case get_req_header(conn, "referer") do
        [referer | _] ->
          uri = URI.parse(referer)
          if uri.query, do: "#{uri.path || "/"}?#{uri.query}", else: uri.path || "/"

        _ ->
          "/"
      end

    redirect(conn, to: path)
  end
end
