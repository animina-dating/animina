defmodule AniminaWeb.LiveStoryComponentTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures
  import Animina.MoodboardFixtures

  describe "LiveStoryComponent rendering via ProfileMoodboard" do
    test "renders markdown content correctly", %{conn: conn} do
      user = user_fixture(language: "en")

      _item =
        story_moodboard_item_fixture(user, "# My Story\n\nThis is **bold** text.", %{
          state: "active"
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      html = render(view)

      # Markdown should be rendered - h1 becomes h2 due to downgrading
      assert html =~ "My Story"
      assert html =~ "<strong>bold</strong>"
    end

    test "renders paragraph breaks correctly", %{conn: conn} do
      user = user_fixture(language: "en")

      _item =
        story_moodboard_item_fixture(user, "First paragraph.\n\nSecond paragraph.", %{
          state: "active"
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      html = render(view)
      assert html =~ "First paragraph."
      assert html =~ "Second paragraph."
    end

    test "renders story in combined card with photo", %{conn: conn} do
      user = user_fixture(language: "en")
      _item = combined_moodboard_item_fixture(user, "My caption text", %{state: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      html = render(view)
      assert html =~ "My caption text"
    end

    test "escapes HTML in markdown content for security", %{conn: conn} do
      user = user_fixture(language: "en")

      _item =
        story_moodboard_item_fixture(user, "<script>alert('xss')</script>", %{state: "active"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user.id}")

      html = render(view)
      # Script tags should be escaped, not rendered as executable HTML
      # The text "script" should appear but not as an actual tag
      refute html =~ "<script>alert"
    end
  end
end
