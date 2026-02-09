defmodule AniminaWeb.LivePhotoComponentTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.PhotosFixtures

  alias Animina.Repo

  describe "Avatar status rendering on avatar upload page" do
    test "renders approved photo without error status", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{state: "approved", width: 800, height: 600})
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)

      # Approved photos should not show error statuses
      refute html =~ "Upload failed"
      refute html =~ "Content violation"
    end

    test "owner sees processing status for processing photo", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{state: "processing"})
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      assert html =~ "Processing"
    end

    test "owner sees analyzing status for ollama_checking photo", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      assert html =~ "Analyzing"
    end

    test "owner sees status for needs_manual_review photo", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{state: "needs_manual_review", width: 800, height: 600})
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      # needs_manual_review shows a status badge on avatar upload page
      assert html =~ "badge"
    end

    test "owner sees error status when photo has error state", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{
          state: "error",
          width: 800,
          height: 600,
          error_message: "nudity detected"
        })
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      assert html =~ "Content violation"
    end

    test "owner sees no face error message", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{
          state: "no_face_error",
          width: 800,
          height: 600,
          error_message: "No face detected"
        })
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      assert html =~ "No face detected"
    end

    test "owner sees appeal pending status", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{state: "appeal_pending", width: 800, height: 600})
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      assert html =~ "Pending moderator review"
    end

    test "owner sees appeal rejected status", %{conn: conn} do
      user = user_fixture(language: "en")

      _photo =
        photo_fixture(%{owner_type: "User", owner_id: user.id, type: "avatar"})
        |> Ecto.Changeset.change(%{state: "appeal_rejected", width: 800, height: 600})
        |> Repo.update!()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/settings/avatar")

      html = render(view)
      assert html =~ "Appeal rejected"
    end
  end
end
