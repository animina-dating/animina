defmodule AniminaWeb.Admin.PhotoDetailLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  describe "Photo Detail page" do
    setup do
      admin = admin_fixture(%{display_name: "TestAdmin", language: "en"})
      user = user_fixture(%{display_name: "PhotoOwner", language: "en"})

      photo =
        approved_photo_fixture(%{
          owner_type: "User",
          owner_id: user.id
        })

      # Description is set via description_changeset, not create_changeset
      {:ok, photo} =
        Animina.Photos.update_photo_description(photo, %{
          description: "A beautiful sunset",
          description_model: "test-model",
          description_generated_at: DateTime.utc_now(:second)
        })

      %{admin: admin, user: user, photo: photo}
    end

    test "requires admin access", %{conn: conn, photo: photo} do
      user = user_fixture(%{language: "en"})
      conn = log_in_user(conn, user)
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/photos/#{photo.id}")
    end

    test "renders photo details for admin", %{conn: conn, admin: admin, photo: photo} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos/#{photo.id}")
      assert html =~ "Photo Details"
      assert html =~ photo.id
    end

    test "shows owner information", %{conn: conn, admin: admin, photo: photo, user: user} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos/#{photo.id}")
      assert html =~ user.display_name
    end

    test "shows photo state", %{conn: conn, admin: admin, photo: photo} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos/#{photo.id}")
      assert html =~ "approved"
    end

    test "shows description", %{conn: conn, admin: admin, photo: photo} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos/#{photo.id}")
      assert html =~ "A beautiful sunset"
    end

    test "shows audit history section", %{conn: conn, admin: admin, photo: photo} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _lv, html} = live(conn, ~p"/admin/photos/#{photo.id}")
      assert html =~ "Audit History"
    end

    test "regenerate description button exists", %{conn: conn, admin: admin, photo: photo} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, lv, _html} = live(conn, ~p"/admin/photos/#{photo.id}")
      assert has_element?(lv, "button", "Regenerate Description")
    end
  end
end
