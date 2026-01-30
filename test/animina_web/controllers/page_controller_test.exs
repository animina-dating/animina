defmodule AniminaWeb.PageControllerTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "ANIMINA"
  end

  describe "root page navigation for non-logged-in users" do
    test "shows login and register links in the navbar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(href="/users/log-in")
      assert html =~ "Log in"
      assert html =~ ~s(href="/users/register")
      assert html =~ "Register"
    end
  end
end
