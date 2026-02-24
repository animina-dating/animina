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

    test "renders privacy settings page with online status toggle", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/my/settings/privacy")

      assert html =~ "Privacy"
      assert html =~ "Online status visible"
      assert html =~ "toggle-success"
    end

    test "toggling online status works", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/privacy")

      html = lv |> element(~s(input[phx-click="toggle_online_status"])) |> render_click()

      assert html =~ "Online status"
    end
  end
end
