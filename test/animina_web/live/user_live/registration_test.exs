defmodule AniminaWeb.UserLive.RegistrationTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Konto erstellen"
      assert html =~ "Jetzt anmelden"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Konto erstellen"
      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form =
        form(lv, "#registration_form",
          user:
            valid_user_attributes(email: email)
            |> Map.delete(:terms_accepted)
            |> Map.put(:terms_accepted, "true")
            |> stringify_keys()
        )

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               ~r/E-Mail wurde an .* gesendet/
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user:
            valid_user_attributes(email: user.email)
            |> Map.delete(:terms_accepted)
            |> Map.put(:terms_accepted, "true")
            |> stringify_keys()
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "progressive section unlocking" do
    test "sections 2-5 are locked initially", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      # Section 1 (Zugangsdaten) should be unlocked
      refute html =~ ~r/id="section-1"[^>]*section-locked/
      # Sections 2-5 should be locked
      assert html =~ ~r/id="section-2"[^>]*section-locked/
      assert html =~ ~r/id="section-3"[^>]*section-locked/
      assert html =~ ~r/id="section-4"[^>]*section-locked/
      assert html =~ ~r/id="section-5"[^>]*section-locked/
    end

    test "filling section 1 unlocks section 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "email" => "test@example.com",
            "password" => "password1234",
            "mobile_phone" => "+4915112345678"
          }
        )

      refute html =~ ~r/id="section-2"[^>]*section-locked/
      assert html =~ ~r/id="section-3"[^>]*section-locked/
    end

    test "filling sections 1-2 unlocks section 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "email" => "test@example.com",
            "password" => "password1234",
            "mobile_phone" => "+4915112345678",
            "country_id" => germany_id(),
            "zip_code" => "10115"
          }
        )

      refute html =~ ~r/id="section-2"[^>]*section-locked/
      refute html =~ ~r/id="section-3"[^>]*section-locked/
      assert html =~ ~r/id="section-4"[^>]*section-locked/
    end

    test "filling sections 1-3 unlocks sections 4 and 5", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "email" => "test@example.com",
            "password" => "password1234",
            "mobile_phone" => "+4915112345678",
            "country_id" => germany_id(),
            "zip_code" => "10115",
            "display_name" => "TestUser",
            "birthday" => "1990-01-01",
            "gender" => "male",
            "height" => "180"
          }
        )

      refute html =~ ~r/id="section-3"[^>]*section-locked/
      refute html =~ ~r/id="section-4"[^>]*section-locked/
      refute html =~ ~r/id="section-5"[^>]*section-locked/
    end

    test "submit button is disabled until section 5 is unlocked", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      # Submit button should be disabled initially
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Konto erstellen/s
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the login link is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Jetzt anmelden")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Anmelden"
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
