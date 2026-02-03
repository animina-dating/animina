defmodule AniminaWeb.Admin.PhotoBlacklistLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.Photos

  describe "PhotoBlacklistLive" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/photo-blacklist")
    end

    test "renders empty state when no blacklist entries", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/photo-blacklist")

      assert html =~ "Photo Blacklist"
      assert html =~ "No blacklist entries yet"
    end

    test "lists blacklist entries", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      # Create a blacklist entry
      dhash = :crypto.strong_rand_bytes(8)
      {:ok, _entry} = Photos.add_to_blacklist(dhash, "Test reason", admin, nil)

      {:ok, _view, html} = live(conn, ~p"/admin/photo-blacklist")

      assert html =~ "Photo Blacklist"
      assert html =~ "Test reason"
      assert html =~ "1 entry"
    end

    test "can delete a blacklist entry", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      dhash = :crypto.strong_rand_bytes(8)
      {:ok, entry} = Photos.add_to_blacklist(dhash, "To be deleted", admin, nil)

      {:ok, view, _html} = live(conn, ~p"/admin/photo-blacklist")

      # Click confirm delete
      view
      |> element("button[phx-click='confirm-delete'][phx-value-id='#{entry.id}']")
      |> render_click()

      # Confirm deletion
      view |> element("button[phx-click='delete'][phx-value-id='#{entry.id}']") |> render_click()

      # Should show success and empty state
      assert render(view) =~ "Blacklist entry deleted"
      assert render(view) =~ "No blacklist entries yet"
    end

    test "can cancel delete confirmation", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      dhash = :crypto.strong_rand_bytes(8)
      {:ok, entry} = Photos.add_to_blacklist(dhash, "Keep this one", admin, nil)

      {:ok, view, _html} = live(conn, ~p"/admin/photo-blacklist")

      # Click confirm delete
      view
      |> element("button[phx-click='confirm-delete'][phx-value-id='#{entry.id}']")
      |> render_click()

      # Cancel deletion
      view |> element("button[phx-click='cancel-delete']") |> render_click()

      # Entry should still be visible
      assert render(view) =~ "Keep this one"
    end
  end
end
