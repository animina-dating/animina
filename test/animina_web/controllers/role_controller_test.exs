defmodule AniminaWeb.RoleControllerTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AccountsFixtures

  describe "POST /role/switch" do
    test "switches to a valid role the user has", %{conn: conn} do
      user = admin_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/role/switch", %{"role" => "admin"})

      # Successful role switch includes ?menu=open to keep dropdown open
      assert redirected_to(conn) == "/?menu=open"
      assert get_session(conn, :current_role) == "admin"
    end

    test "rejects switching to a role the user doesn't have", %{conn: conn} do
      user = user_fixture(%{language: "en"})

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/role/switch", %{"role" => "admin"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "do not have that role"
    end

    test "allows switching back to user role", %{conn: conn} do
      user = admin_fixture()

      conn =
        conn
        |> log_in_user(user, current_role: "admin")
        |> post(~p"/role/switch", %{"role" => "user"})

      # Successful role switch includes ?menu=open to keep dropdown open
      assert redirected_to(conn) == "/?menu=open"
      assert get_session(conn, :current_role) == "user"
    end

    test "redirects back to referer with menu=open param", %{conn: conn} do
      user = admin_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> put_req_header("referer", "http://localhost:4000/settings")
        |> post(~p"/role/switch", %{"role" => "admin"})

      # Successful role switch includes ?menu=open to keep dropdown open
      assert redirected_to(conn) == "/settings?menu=open"
    end

    test "requires authentication", %{conn: conn} do
      conn = post(conn, ~p"/role/switch", %{"role" => "admin"})
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
