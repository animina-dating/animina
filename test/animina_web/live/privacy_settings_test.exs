defmodule AniminaWeb.UserLive.PrivacySettingsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Privacy Settings page" do
    setup %{conn: conn} do
      user = user_fixture(language: "en")
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "renders privacy settings page with wingman toggle", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/my/settings/privacy")

      assert html =~ "Privacy &amp; Blocking"
      assert html =~ "Wingman"
      assert html =~ "toggle-success"
    end

    test "toggling wingman off shows inactive badge", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/privacy")

      html = lv |> element(~s(input[phx-click="toggle_wingman"])) |> render_click()

      assert html =~ "Wingman is now inactive."
    end

    test "toggling wingman back on shows active message", %{conn: conn, user: user} do
      # First disable wingman
      {:ok, _user} =
        Animina.Accounts.update_wingman_enabled(user, %{wingman_enabled: false})

      {:ok, lv, _html} = live(conn, ~p"/my/settings/privacy")

      html = lv |> element(~s(input[phx-click="toggle_wingman"])) |> render_click()

      assert html =~ "Wingman is now active."
    end
  end
end
