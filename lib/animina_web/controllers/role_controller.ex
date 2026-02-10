defmodule AniminaWeb.RoleController do
  use AniminaWeb, :controller

  alias Animina.Accounts
  import AniminaWeb.Helpers.ControllerHelpers, only: [redirect_back: 1]

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
end
