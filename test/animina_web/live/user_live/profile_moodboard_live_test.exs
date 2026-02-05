defmodule AniminaWeb.UserLive.ProfileMoodboardLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "ProfileMoodboardLive access control" do
    test "owner can access their own moodboard", %{conn: conn} do
      user = user_fixture(language: "en")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/moodboard/#{user.id}")

      assert html =~ "Moodboard"
      assert html =~ user.display_name
    end

    test "anonymous user sees vague denial and is redirected to /", %{conn: conn} do
      user = user_fixture(language: "en")

      assert {:error, redirect} = live(conn, ~p"/moodboard/#{user.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "logged-in non-owner sees vague denial and is redirected to /", %{conn: conn} do
      owner = user_fixture(language: "en")
      other_user = user_fixture(language: "en")

      assert {:error, redirect} =
               conn
               |> log_in_user(other_user)
               |> live(~p"/moodboard/#{owner.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "non-existent user_id shows same vague denial (indistinguishable from non-owner)", %{
      conn: conn
    } do
      random_uuid = Ecto.UUID.generate()

      assert {:error, redirect} = live(conn, ~p"/moodboard/#{random_uuid}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end

    test "non-existent user_id shows same denial for logged-in user", %{conn: conn} do
      user = user_fixture(language: "en")
      random_uuid = Ecto.UUID.generate()

      assert {:error, redirect} =
               conn
               |> log_in_user(user)
               |> live(~p"/moodboard/#{random_uuid}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "This page doesn't exist or you don't have access."} = flash
    end
  end
end
