defmodule AniminaWeb.Plugs.RequireAdminPathTest do
  use AniminaWeb.ConnCase, async: true

  alias Animina.Accounts.Scope
  alias AniminaWeb.Plugs.RequireAdminPath

  import Animina.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, AniminaWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> fetch_flash()

    %{conn: conn}
  end

  describe "call/2 — admin paths" do
    test "blocks unauthenticated user from /admin path", %{conn: conn} do
      conn =
        conn
        |> Map.put(:request_path, "/admin/roles")
        |> RequireAdminPath.call([])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "blocks regular user from /admin path", %{conn: conn} do
      user = user_fixture(%{language: "en"})
      scope = Scope.for_user(user)

      conn =
        conn
        |> assign(:current_scope, scope)
        |> Map.put(:request_path, "/admin/roles")
        |> RequireAdminPath.call([])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "allows admin user through /admin path", %{conn: conn} do
      user = user_fixture(%{language: "en"})
      scope = Scope.for_user(user, ["user", "admin"], "admin")

      conn =
        conn
        |> assign(:current_scope, scope)
        |> Map.put(:request_path, "/admin/roles")
        |> RequireAdminPath.call([])

      refute conn.halted
    end

    test "blocks moderator (non-admin) from /admin path", %{conn: conn} do
      user = user_fixture(%{language: "en"})
      scope = Scope.for_user(user, ["user", "moderator"], "moderator")

      conn =
        conn
        |> assign(:current_scope, scope)
        |> Map.put(:request_path, "/admin/photo-reviews")
        |> RequireAdminPath.call([])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end
  end

  describe "call/2 — non-admin paths" do
    test "does not affect non-admin paths for unauthenticated user", %{conn: conn} do
      conn =
        conn
        |> Map.put(:request_path, "/settings")
        |> RequireAdminPath.call([])

      refute conn.halted
    end

    test "does not affect non-admin paths for regular user", %{conn: conn} do
      user = user_fixture(%{language: "en"})
      scope = Scope.for_user(user)

      conn =
        conn
        |> assign(:current_scope, scope)
        |> Map.put(:request_path, "/discover")
        |> RequireAdminPath.call([])

      refute conn.halted
    end

    test "does not affect root path", %{conn: conn} do
      conn =
        conn
        |> Map.put(:request_path, "/")
        |> RequireAdminPath.call([])

      refute conn.halted
    end
  end
end
