defmodule AniminaWeb.RootTest do
  use AniminaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "checks the home page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert render(view) =~ "Animina Dating Plattform"
  end
end
