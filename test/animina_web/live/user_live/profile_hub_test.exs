defmodule AniminaWeb.UserLive.ProfileHubTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Profile Hub redirect" do
    test "redirects /my-profile to /settings", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(language: "en"))

      assert {:error, {:live_redirect, %{to: "/settings"}}} = live(conn, ~p"/my-profile")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my-profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end
end
