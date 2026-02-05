defmodule AniminaWeb.Admin.OllamaQueueLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.PhotosFixtures

  alias Animina.Photos

  # Helper to create a photo in ollama_checking state
  defp ollama_checking_photo(user_id) do
    photo = photo_fixture(%{owner_id: user_id})

    photo
    |> Ecto.Changeset.change(%{state: "ollama_checking", width: 800, height: 600})
    |> Animina.Repo.update!()
  end

  setup do
    admin = Animina.AccountsFixtures.user_fixture()
    Animina.Accounts.assign_role(admin, "admin")

    user = Animina.AccountsFixtures.user_fixture()

    %{admin: admin, user: user}
  end

  describe "access control" do
    test "requires admin role", %{conn: conn} do
      user = Animina.AccountsFixtures.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/admin/ollama-queue")

      assert redirected_to(conn) =~ "/"
    end

    test "accessible with admin role", %{conn: conn, admin: admin} do
      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      assert html =~ "Ollama Queue"
    end
  end

  describe "empty queue" do
    test "shows empty state message", %{conn: conn, admin: admin} do
      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      assert html =~ "No photos in queue"
    end
  end

  describe "queue with photos" do
    test "displays photos in queue", %{conn: conn, admin: admin, user: user} do
      # Create a photo in the queue
      photo = ollama_checking_photo(user.id)
      {:ok, _photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      assert html =~ "1 photo pending"
    end

    test "shows stats cards", %{conn: conn, admin: admin, user: user} do
      photo = ollama_checking_photo(user.id)
      {:ok, _photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, _view, html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      assert html =~ "Queue Size"
      assert html =~ "Processed"
      assert html =~ "Succeeded"
      assert html =~ "Failed"
    end

    test "filters by state", %{conn: conn, admin: admin, user: user} do
      # Create photos in different states
      photo1 = ollama_checking_photo(user.id)
      {:ok, _} = Photos.queue_for_ollama_retry(photo1)

      photo2 = ollama_checking_photo(user.id)

      {:ok, photo2} =
        photo2
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Animina.Repo.update()

      {:ok, _} = Photos.queue_for_ollama_retry(photo2)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      # Filter to pending_ollama
      html =
        view
        |> element("select[name=state]")
        |> render_change(%{state: "pending_ollama"})

      assert html =~ "1 photo pending"

      # Filter to needs_manual_review
      html =
        view
        |> element("select[name=state]")
        |> render_change(%{state: "needs_manual_review"})

      assert html =~ "1 photo pending"
    end
  end

  describe "photo review modal" do
    test "opens modal when clicking photo", %{conn: conn, admin: admin, user: user} do
      photo = ollama_checking_photo(user.id)
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      html =
        view
        |> element("[phx-click='select-photo'][phx-value-id='#{photo.id}']")
        |> render_click()

      assert html =~ "Review Photo"
      assert html =~ "Retry Count"
    end

    test "approves photo from modal", %{conn: conn, admin: admin, user: user} do
      photo = ollama_checking_photo(user.id)
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      view
      |> element("[phx-click='select-photo'][phx-value-id='#{photo.id}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='approve']")
        |> render_click()

      assert html =~ "Photo approved"

      # Verify photo state changed
      updated = Photos.get_photo!(photo.id)
      assert updated.state == "approved"
    end

    test "rejects photo from modal", %{conn: conn, admin: admin, user: user} do
      photo = ollama_checking_photo(user.id)
      {:ok, photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      view
      |> element("[phx-click='select-photo'][phx-value-id='#{photo.id}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='reject']")
        |> render_click()

      assert html =~ "Photo rejected"

      # Verify photo state changed
      updated = Photos.get_photo!(photo.id)
      assert updated.state == "error"
    end

    test "shows retry button for needs_manual_review photos", %{
      conn: conn,
      admin: admin,
      user: user
    } do
      photo = ollama_checking_photo(user.id)

      {:ok, photo} =
        photo
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Animina.Repo.update()

      {:ok, photo} = Photos.queue_for_ollama_retry(photo)
      assert photo.state == "needs_manual_review"

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      html =
        view
        |> element("[phx-click='select-photo'][phx-value-id='#{photo.id}']")
        |> render_click()

      assert html =~ "Retry"
    end

    test "retry action queues photo for retry", %{conn: conn, admin: admin, user: user} do
      photo = ollama_checking_photo(user.id)

      {:ok, photo} =
        photo
        |> Ecto.Changeset.change(%{ollama_retry_count: 20})
        |> Animina.Repo.update()

      {:ok, photo} = Photos.queue_for_ollama_retry(photo)

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue")

      view
      |> element("[phx-click='select-photo'][phx-value-id='#{photo.id}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='retry']")
        |> render_click()

      assert html =~ "Photo queued for retry"

      # Verify photo state changed
      updated = Photos.get_photo!(photo.id)
      assert updated.state == "pending_ollama"
      assert updated.ollama_retry_count == 0
    end
  end

  describe "pagination" do
    test "navigates between pages", %{conn: conn, admin: admin, user: user} do
      # Create enough photos to paginate (using small per_page)
      for _i <- 1..3 do
        photo = ollama_checking_photo(user.id)
        Photos.queue_for_ollama_retry(photo)
      end

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> switch_role("admin")
        |> live(~p"/admin/ollama-queue?per_page=2")

      assert render(view) =~ "Page 1 of 2"

      # Navigate to next page
      html =
        view
        |> element("button[phx-click='go-to-page'][phx-value-page='2']")
        |> render_click()

      assert html =~ "Page 2 of 2"
    end
  end

  # Helper to switch to admin role
  defp switch_role(conn, role) do
    conn
    |> post(~p"/role/switch", %{role: role})
    |> recycle()
  end
end
