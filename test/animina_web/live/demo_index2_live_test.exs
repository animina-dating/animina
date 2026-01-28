defmodule AniminaWeb.DemoIndex2LiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /demo/index2" do
    test "renders landing page with German content", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/demo/index2")

      # Check page title/heading
      assert html =~ "ANIMINA"

      # Check key differentiators are present in German
      assert html =~ "100% Kostenlos"
      assert html =~ "Open Source"
      assert html =~ "Wir finanzieren uns durch Werbung"

      # Check for personality system mention
      assert html =~ "Persönlichkeit"

      # Check for 5 contacts per day limit
      assert html =~ "5 Kontakte pro Tag"

      # Check CTA button exists
      assert html =~ "Jetzt registrieren"

      # Verify the page is rendered by the correct module
      assert has_element?(view, "header")
      assert has_element?(view, "main")
      assert has_element?(view, "footer")
    end

    test "displays happy faces imagery section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo/index2")

      # Check for images (Unsplash photos)
      assert html =~ "unsplash.com"
    end

    test "highlights open source transparency", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo/index2")

      # Check open source messaging
      assert html =~ "Open Source" or html =~ "open-source" or html =~ "quelloffen"
      assert html =~ "Algorithmus" or html =~ "fair"
    end
  end
end
