defmodule AniminaWeb.ImpressumLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /impressum" do
    test "renders the Impressum page with key content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/impressum")

      assert html =~ "Impressum"
      assert html =~ "Stefan Wintermeyer"
      assert html =~ "Johannes-Müller-Str. 10"
      assert html =~ "56068 Koblenz"
      assert html =~ "Haftung für Inhalte"
      assert html =~ "Haftung für Links"
      assert html =~ "Urheberrecht"
    end

    test "renders shared layout with ANIMINA nav", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/impressum")

      assert html =~ "ANIMINA"
    end
  end
end
