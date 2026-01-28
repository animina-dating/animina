defmodule AniminaWeb.DemoLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Demo page" do
    test "renders the demo page with navbar and hero section", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/demo")

      # Check navbar elements
      assert html =~ "animina"
      assert has_element?(view, "header nav")

      # Check hero section
      assert html =~ "Find meaningful"
      assert html =~ "connections"
      assert html =~ "Get started"

      # Check footer
      assert html =~ "All rights reserved"
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

    test "bookmark dropdown toggles on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/demo")

      # Initially dropdown should not show saved profiles content
      refute has_element?(view, "h3", "Saved Profiles")

      # Click the bookmark button to open dropdown
      view |> element("button[aria-label='Bookmarks']") |> render_click()

      # Now the dropdown should be visible
      assert has_element?(view, "h3", "Saved Profiles")
      assert has_element?(view, "a", "View all saved")

      # Check bookmark items
      assert render(view) =~ "Sarah"
      assert render(view) =~ "Marcus"
      assert render(view) =~ "Elena"
    end

    test "message counter shows correct count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      # Check message counter badge exists and shows "3"
      # The badge is inside a span with the count
      assert html =~ ~r/class=".*bg-primary rounded-full".*>\s*3\s*<\/span>/s
    end

    test "page has proper accessibility attributes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      # Check aria-labels on buttons
      assert html =~ "aria-label=\"Messages\""
      assert html =~ "aria-label=\"Bookmarks\""
      assert html =~ "aria-label=\"Your profile\""
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
