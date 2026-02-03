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
      |> redirect_back(keep_menu_open: true)
    else
      conn
      |> put_flash(:error, gettext("You do not have that role."))
      |> redirect_back()
    end
  end

  def switch(conn, _params) do
    redirect_back(conn)
  end

  defp redirect_back(conn, opts \\ []) do
    keep_menu_open = Keyword.get(opts, :keep_menu_open, false)

    path =
      case get_req_header(conn, "referer") do
        [referer | _] ->
          uri = URI.parse(referer)
          base_path = uri.path || "/"

          # Build query params, adding menu=open if needed
          existing_params =
            if uri.query, do: URI.decode_query(uri.query), else: %{}

          params =
            if keep_menu_open,
              do: Map.put(existing_params, "menu", "open"),
              else: existing_params

          if map_size(params) > 0,
            do: "#{base_path}?#{URI.encode_query(params)}",
            else: base_path

        _ ->
          if keep_menu_open, do: "/?menu=open", else: "/"
      end

    redirect(conn, to: path)
  end
end
