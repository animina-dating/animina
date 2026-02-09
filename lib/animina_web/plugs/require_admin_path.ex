defmodule AniminaWeb.Plugs.RequireAdminPath do
  @moduledoc """
  Defense-in-depth plug that blocks any request to `/admin/*` unless
  the current user has the admin role.

  This acts as a safety net at the connection level — before any LiveView
  mounts — so that even a misconfigured route under `/admin` cannot be
  reached by non-admin users.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]
  use Gettext, backend: AniminaWeb.Gettext

  alias Animina.Accounts.Scope

  def init(opts), do: opts

  def call(%{request_path: "/admin" <> _} = conn, _opts) do
    scope = conn.assigns[:current_scope]

    if scope && Scope.admin?(scope) do
      conn
    else
      conn
      |> put_flash(:error, gettext("You are not authorized to access this page."))
      |> redirect(to: "/")
      |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
