defmodule AniminaWeb.UserLive.AvatarUploadTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  alias Animina.Photos

  describe "Avatar Upload page" do
    test "renders upload form for authenticated user", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/avatar")

      assert html =~ "Profile Photo"
      assert html =~ "Upload a photo"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/avatar")

      assert page_title(lv) == "Profile Photo - ANIMINA"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/users/settings/avatar")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/users/settings']")
      assert html =~ "Profile Photo"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings/avatar")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "shows placeholder when no avatar exists", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Should show initial placeholder (first letter of display name)
      assert has_element?(lv, "[data-role='avatar-placeholder']")
    end

    test "displays approved avatar image", %{conn: conn} do
      user = user_fixture(language: "en")
      _avatar = approved_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      assert has_element?(lv, "[data-role='avatar-image']")
      refute has_element?(lv, "[data-role='status-badge']")
    end

    test "shows placeholder with processing indicator for pending photo", %{conn: conn} do
      user = user_fixture(language: "en")
      _pending = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Should show placeholder (not the image) since file isn't processed yet
      refute has_element?(lv, "[data-role='avatar-image']")
      assert has_element?(lv, "[data-role='avatar-placeholder']")
      # Should show the processing progress indicator (not status badge)
      assert has_element?(lv, "[data-role='processing-progress']")
      assert html =~ "Pending review"
    end

    test "shows processing badge for processing state", %{conn: conn} do
      user = user_fixture(language: "en")
      photo = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      photo
      |> Ecto.Changeset.change(%{state: "processing"})
      |> Animina.Repo.update!()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      assert html =~ "Processing"
    end

    test "shows analyzing photo badge for ollama_checking state", %{conn: conn} do
      user = user_fixture(language: "en")
      photo = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      photo
      |> Ecto.Changeset.change(%{state: "ollama_checking"})
      |> Animina.Repo.update!()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      assert html =~ "Analyzing photo"
    end

    test "shows no face detected error badge", %{conn: conn} do
      user = user_fixture(language: "en")

      photo =
        no_face_error_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      # Create the processed files so the image can be served
      create_processed_files(photo)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      assert has_element?(lv, "[data-role='status-badge']")
      # Should still show the image (so user can see what was rejected)
      assert has_element?(lv, "[data-role='avatar-image']")
    end

    test "status badge updates when photo transitions to no_face_error", %{conn: conn} do
      user = user_fixture(language: "en")
      photo = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      photo
      |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
      |> Animina.Repo.update!()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Initially shows processing indicator
      assert has_element?(lv, "[data-role='processing-progress']")

      # Simulate Ollama check failure via PubSub
      rejected_photo =
        photo
        |> Ecto.Changeset.change(%{
          state: "no_face_error",
          width: 800,
          height: 600,
          error_message: "Photo must show exactly one person facing the camera"
        })
        |> Animina.Repo.update!()

      # Create processed files so the image can be shown
      create_processed_files(rejected_photo)

      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        "photos:User:#{user.id}",
        {:photo_state_changed, rejected_photo}
      )

      # After state change, should show status badge instead of processing indicator
      refute has_element?(lv, "[data-role='processing-progress']")
      assert has_element?(lv, "[data-role='status-badge']")
    end

    test "uploads file and creates pending photo", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Create a test image
      image_path = create_test_image()

      # Upload the file
      avatar =
        file_input(lv, "#avatar-upload-form", :avatar, [
          %{
            name: "test.png",
            content: File.read!(image_path),
            type: "image/png"
          }
        ])

      assert render_upload(avatar, "test.png") =~ ""

      # Submit the form
      lv
      |> form("#avatar-upload-form")
      |> render_submit()

      # Verify photo was created
      photo = Photos.get_user_avatar_any_state(user.id)
      assert photo != nil
      assert photo.state == "pending"
      assert photo.type == "avatar"

      # Clean up
      File.rm(image_path)
    end

    test "replaces existing avatar on new upload", %{conn: conn} do
      user = user_fixture(language: "en")

      old_avatar =
        approved_photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Create a test image
      image_path = create_test_image()

      # Upload the new file
      avatar =
        file_input(lv, "#avatar-upload-form", :avatar, [
          %{
            name: "new_test.png",
            content: File.read!(image_path),
            type: "image/png"
          }
        ])

      render_upload(avatar, "new_test.png")

      lv
      |> form("#avatar-upload-form")
      |> render_submit()

      # Old avatar should be deleted
      assert Photos.get_photo(old_avatar.id) == nil

      # New avatar should exist
      new_photo = Photos.get_user_avatar_any_state(user.id)
      assert new_photo != nil
      assert new_photo.id != old_avatar.id

      # Clean up
      File.rm(image_path)
    end

    test "validates file type", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Try to upload an invalid file type
      avatar =
        file_input(lv, "#avatar-upload-form", :avatar, [
          %{
            name: "test.txt",
            content: "not an image",
            type: "text/plain"
          }
        ])

      assert {:error, [[_, :not_accepted]]} = render_upload(avatar, "test.txt")
    end

    test "processing indicator updates in real-time when photo state changes", %{conn: conn} do
      user = user_fixture(language: "en")
      photo = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Initially shows processing indicator for pending photo
      assert has_element?(lv, "[data-role='processing-progress']")
      assert html =~ "Pending review"

      # Simulate state change via PubSub (as PhotoProcessor would do)
      approved_photo =
        photo
        |> Ecto.Changeset.change(%{state: "approved"})
        |> Animina.Repo.update!()

      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        "photos:User:#{user.id}",
        {:photo_state_changed, approved_photo}
      )

      # Processing indicator should disappear after state change
      updated_html = render(lv)
      refute updated_html =~ "Pending review"
      refute has_element?(lv, "[data-role='processing-progress']")
      assert has_element?(lv, "[data-role='avatar-image']")
    end

    test "processing indicator disappears when receiving photo_approved message", %{conn: conn} do
      user =
        user_fixture(language: "en")
        |> Ecto.Changeset.change(%{state: "normal"})
        |> Animina.Repo.update!()

      photo = photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings/avatar")

      # Initially shows processing indicator for pending photo
      assert has_element?(lv, "[data-role='processing-progress']")

      # Simulate approval via PubSub
      approved_photo =
        photo
        |> Ecto.Changeset.change(%{state: "approved"})
        |> Animina.Repo.update!()

      Phoenix.PubSub.broadcast(
        Animina.PubSub,
        "photos:User:#{user.id}",
        {:photo_approved, approved_photo}
      )

      # Processing indicator should disappear after approval
      refute has_element?(lv, "[data-role='processing-progress']")
      assert has_element?(lv, "[data-role='avatar-image']")
    end
  end
end
