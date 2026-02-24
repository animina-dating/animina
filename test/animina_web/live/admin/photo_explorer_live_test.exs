defmodule AniminaWeb.Admin.PhotoExplorerLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  describe "Photo Explorer page" do
    setup do
      admin = admin_fixture(%{display_name: "TestAdmin", language: "en"})
      user = user_fixture(%{display_name: "SearchableUser", language: "en"})

      photo =
        approved_photo_fixture(%{
          owner_type: "User",
          owner_id: user.id
        })

      %{admin: admin, user: user, photo: photo}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture(%{language: "en"})
      conn = log_in_user(conn, user)
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/photos")
    end

    test "renders search page for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos")
      assert html =~ "Photo Explorer"
    end

    test "search by display name returns results", %{conn: conn, admin: admin, user: user} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin/photos")

      html =
        lv
        |> element("#photo-search")
        |> render_change(%{"query" => "SearchableUser"})

      assert html =~ user.display_name
    end

    test "empty search shows prompt", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos")
      assert html =~ "Enter a search term"
    end

    test "no results shows message", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin/photos")

      html =
        lv
        |> element("#photo-search")
        |> render_change(%{"query" => "zzz_nonexistent_zzz"})

      assert html =~ "No photos found"
    end

    test "state filter works", %{conn: conn, admin: admin, user: user} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin/photos")

      # Search first
      lv |> element("#photo-search") |> render_change(%{"query" => "SearchableUser"})

      # Filter by error state (should find nothing since photo is approved)
      html =
        lv
        |> element("#state-filter")
        |> render_change(%{"state" => "error"})

      assert html =~ "No photos found"

      # Filter by approved state (should find the photo)
      html =
        lv
        |> element("#state-filter")
        |> render_change(%{"state" => "approved"})

      assert html =~ user.display_name
    end
  end
end
