defmodule AniminaWeb.UserLive.SettingsTest do
  use AniminaWeb.ConnCase, async: true

  alias Animina.Accounts
  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Account hub page" do
    test "renders account hub with 4 cards", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account")

      assert html =~ "Email &amp; Password"
      assert html =~ "Passkeys"
      assert html =~ "Active Sessions"
      assert html =~ "Delete Account"
    end

    test "has page title", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account")

      assert page_title(lv) =~ "Account"
    end

    test "has breadcrumbs", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account")

      assert html =~ "breadcrumbs"
      assert has_element?(lv, ".breadcrumbs a[href='/my/settings']")
      assert html =~ "Account"
    end

    test "has navigation links to sub-pages", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account")

      assert has_element?(lv, "a[href='/my/settings/account/email-password']")
      assert has_element?(lv, "a[href='/my/settings/account/passkeys']")
      assert has_element?(lv, "a[href='/my/settings/account/sessions']")
      assert has_element?(lv, "a[href='/my/settings/account/delete']")
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/settings/account")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(language: "en"),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/my/settings/account")
        |> follow_redirect(
          conn,
          ~p"/users/log-in" <> "?sudo_return_to=%2Fmy%2Fsettings%2Faccount"
        )

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "Email & Password page" do
    test "renders email and password forms", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account/email-password")

      assert html =~ "Change Email"
      assert html =~ "Save Password"
    end

    test "has breadcrumbs back to account hub", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account/email-password")

      assert has_element?(lv, ".breadcrumbs a[href='/my/settings']")
      assert has_element?(lv, ".breadcrumbs a[href='/my/settings/account']")
    end
  end

  describe "pending email change" do
    setup %{conn: conn} do
      user = user_fixture(language: "en")
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows pending email info when email change is pending", %{conn: conn, user: user} do
      new_email = unique_user_email()

      Accounts.deliver_user_update_email_instructions(
        %{user | email: new_email},
        user.email,
        &"/my/settings/confirm-email/#{&1}"
      )

      {:ok, _lv, html} = live(conn, ~p"/my/settings/account/email-password")

      assert html =~ user.email
      assert html =~ new_email
      assert html =~ "confirmation link has been sent"
    end

    test "does not show pending email info when no change is pending", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/my/settings/account/email-password")

      refute html =~ "confirmation link has been sent"
    end

    test "shows pending email after submitting email change", %{conn: conn} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      result =
        lv
        |> form("#email_form", %{"user" => %{"email" => new_email}})
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert result =~ new_email
      assert result =~ "confirmation link has been sent"
    end
  end

  describe "dev mailbox link" do
    test "dev mailbox link is hidden when dev_routes is not enabled", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture(language: "en"))
        |> live(~p"/my/settings/account/email-password")

      refute html =~ "Open dev mailbox"
      refute html =~ "/dev/mailbox"
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture(language: "en")
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      user = user_fixture(language: "en")
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user password", %{conn: conn, user: user} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/my/settings/account/email-password"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/account/email-password")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture(language: "en")
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/my/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/my/settings/account/email-password"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again — blocked by security cooldown
      {:error, redirect} = live(conn, ~p"/my/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/my/settings/account/email-password"
      assert %{"error" => message} = flash

      assert message == "Cannot change email while a recent account change is being reviewed." or
               message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/my/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/my/settings/account/email-password"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/my/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
