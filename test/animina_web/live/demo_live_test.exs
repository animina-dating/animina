defmodule AniminaWeb.DemoLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Demo page" do
    test "renders the demo page with shared navbar and hero section", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/demo")

      # Check shared navbar from Layouts.app
      assert html =~ "ANIMINA"
      assert has_element?(view, "header nav")

      # Check hero section
      assert html =~ "Find meaningful"
      assert html =~ "connections"
      assert html =~ "Get started"

      # Check shared footer from Layouts.app
      assert html =~ "Open Source"
    end

    test "renders profile cards with proper content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      # Check profile cards are rendered
      assert html =~ "Julia"
      assert html =~ "Thomas"
      assert html =~ "Sofia"

      # Check locations
      assert html =~ "Berlin"
      assert html =~ "Munich"
      assert html =~ "Hamburg"
    end

    test "renders feature section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      assert html =~ "Why Animina?"
      assert html =~ "Verified profiles"
      assert html =~ "Meaningful conversations"
      assert html =~ "Real connections"
    end

    test "images have proper alt text with Unsplash attribution", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      # Check Unsplash attribution in alt tags
      assert html =~ "Photo by Christopher Campbell on Unsplash"
      assert html =~ "Photo by Joseph Gonzalez on Unsplash"
      assert html =~ "Photo by Aiony Haust on Unsplash"
      assert html =~ "Photo by Brooke Cagle on Unsplash"
    end
  end
end
