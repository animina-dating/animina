defmodule AniminaWeb.UserLive.RegistrationTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  defp fill_step_1(lv) do
    lv
    |> element("#registration_form")
    |> render_change(
      user: %{
        "email" => "test@example.com",
        "password" => "password1234",
        "mobile_phone" => "+4915112345678",
        "birthday" => "1990-01-01"
      }
    )

    lv |> element("button[phx-click=next_step]") |> render_click()
  end

  defp fill_step_2(lv) do
    lv
    |> element("#registration_form")
    |> render_change(
      user: %{
        "display_name" => "TestUser",
        "gender" => "male",
        "height" => "180"
      }
    )

    lv |> element("button[phx-click=next_step]") |> render_click()
  end

  describe "Registration page" do
    test "renders registration page with step 1 visible", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Konto erstellen"
      assert html =~ "Jetzt anmelden"
      # Step 1 fields visible
      assert html =~ "E-Mail-Adresse"
      assert html =~ "Passwort"
      assert html =~ "Handynummer"
      assert html =~ "Geburtstag"
      # Step 1 should show "Weiter" button, not "Konto erstellen" submit
      assert html =~ "Weiter"
      refute html =~ ~r/<button[^>]*type="submit"[^>]*>.*Konto erstellen/s
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data on step 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "wizard navigation" do
    test "renders step indicator with 4 steps", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Zugang"
      assert html =~ "Profil"
      assert html =~ "Wohnort"
      assert html =~ "Partner"
    end

    test "step 1 only shows Weiter button, no Zurück", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Weiter"
      refute html =~ "Zurück"
    end

    test "Weiter button is disabled when required step 1 fields are empty", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      # Button should be disabled on initial load (no fields filled)
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Weiter/s
    end

    test "Weiter button becomes enabled when step 1 fields are valid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "email" => "test@example.com",
            "password" => "password1234",
            "mobile_phone" => "+4915112345678",
            "birthday" => "1990-01-01"
          }
        )

      # Button should now be enabled
      refute html =~ ~r/<button[^>]*disabled[^>]*phx-click="next_step"/s
    end

    test "advances to step 2 when step 1 fields are valid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Fill step 1 fields
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      # Click next
      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Should now show step 2 fields
      assert html =~ "Anzeigename"
      assert html =~ "Geschlecht"
      # Should have both Zurück and Weiter
      assert html =~ "Zurück"
      assert html =~ "Weiter"
    end

    test "back button works without validation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Fill step 1 and advance
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Now go back
      html = lv |> element("button", "Zurück") |> render_click()

      # Should be back on step 1
      assert html =~ "E-Mail-Adresse"
      refute html =~ "Zurück"
    end

    test "data persists across steps", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Fill step 1
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Fill step 2
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "display_name" => "TestUser",
          "gender" => "female",
          "height" => "165"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Go back to step 1
      lv |> element("button", "Zurück") |> render_click()
      html = lv |> element("button", "Zurück") |> render_click()

      # Step 1 data should still be there
      assert html =~ "test@example.com"
    end

    test "shows display_name in navbar after completing step 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Fill step 1 and advance
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Fill step 2 with display_name and advance
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "display_name" => "TestUser",
          "gender" => "male",
          "height" => "180"
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Navbar should show the display_name and initial in the avatar
      assert html =~ "TestUser"
      assert html =~ ~r/text-secondary-content">\s*T\s*<\/span>/
    end

    test "advances through all 4 steps", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Step 3 - fill location
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 4 should show partner preferences AND legal checkbox
      assert html =~ "Bevorzugtes Geschlecht"
      assert html =~ "Suchradius"
      assert html =~ "Allgemeinen Geschäftsbedingungen"
      # Step 4 should show "Konto erstellen" instead of "Weiter"
      assert html =~ "Konto erstellen"
    end

    test "auto-fills partner preferences when advancing to step 4", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Step 3
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Partner preferences should be auto-filled
      # Age for 1990-01-01 is 36 -> min 31, max 41
      assert html =~ ~s(value="31")
      assert html =~ ~s(value="41")
    end
  end

  describe "register user via wizard" do
    test "full wizard flow creates account", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      # Step 1
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => email,
          "password" => "password1234",
          "mobile_phone" => unique_mobile_phone(),
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 2
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "display_name" => "TestUser",
          "gender" => "male",
          "height" => "180"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 3
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      {:ok, _lv, html} =
        lv
        |> form("#registration_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ ~r/E-Mail wurde an .* gesendet/
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      # Step 1
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => user.email,
          "password" => "password1234",
          "mobile_phone" => unique_mobile_phone(),
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 2
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "display_name" => "TestUser",
          "gender" => "male",
          "height" => "180"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 3
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      result =
        lv
        |> form("#registration_form")
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "partner age fields" do
    test "shows age fields in step 4", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Step 3
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      assert html =~ "Mindestalter Partner"
      assert html =~ "Höchstalter Partner"
    end

    test "converts partner ages to offsets when saving", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      # Step 1
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => email,
          "password" => "password1234",
          "mobile_phone" => unique_mobile_phone(),
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 2
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "display_name" => "TestUser",
          "gender" => "male",
          "height" => "180"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 3
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 4 - override auto-filled values
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "partner_minimum_age" => "25",
          "partner_maximum_age" => "45",
          "terms_accepted" => "true"
        }
      )

      {:ok, _lv, html} =
        lv
        |> form("#registration_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ ~r/E-Mail wurde an .* gesendet/

      # Verify the offsets were correctly computed
      user = Animina.Repo.get_by!(Animina.Accounts.User, email: email)
      assert user.partner_minimum_age_offset == 11
      assert user.partner_maximum_age_offset == 9
    end
  end

  describe "multiple locations" do
    test "step 3 shows one location by default", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      html = fill_step_2(lv)

      # Should show one location card and the add button
      assert html =~ "Postleitzahl"
      assert html =~ "Weiteren Wohnsitz hinzufügen"
      # Should NOT show delete button when only 1 location
      refute html =~ "Wohnsitz entfernen"
    end

    test "can add a second location", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Add a second location
      html = lv |> element("button", "Weiteren Wohnsitz hinzufügen") |> render_click()

      # Should now show two location cards and delete buttons
      assert html =~ "location-1"
      assert html =~ "location-2"
      assert html =~ "Wohnsitz entfernen"
      # Title should switch to plural
      assert html =~ "Wohnorte"
    end

    test "can remove a location", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Add a second location
      lv |> element("button", "Weiteren Wohnsitz hinzufügen") |> render_click()

      # Remove the second location
      html = lv |> element("button[phx-value-id=\"2\"]") |> render_click()

      # Should be back to one location, no delete button
      assert html =~ "location-1"
      refute html =~ "location-2"
      refute html =~ "Wohnsitz entfernen"
      # Title should switch back to singular
      assert html =~ "3. Wohnort"
    end

    test "cannot add more than 4 locations", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Add 3 more locations (total 4)
      lv |> element("button", "Weiteren Wohnsitz hinzufügen") |> render_click()
      lv |> element("button", "Weiteren Wohnsitz hinzufügen") |> render_click()
      html = lv |> element("button", "Weiteren Wohnsitz hinzufügen") |> render_click()

      # Should have 4 locations and no add button
      assert html =~ "location-1"
      assert html =~ "location-4"
      refute html =~ "Weiteren Wohnsitz hinzufügen"
    end

    test "blocks advancement when two locations have the same zip code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Fill first location
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "locations" => %{"1" => %{"country_id" => germany_id(), "zip_code" => "10115"}}
        }
      )

      # Add second location with same zip code
      lv |> element("button", "Weiteren Wohnsitz hinzufügen") |> render_click()

      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "locations" => %{
              "1" => %{"country_id" => germany_id(), "zip_code" => "10115"},
              "2" => %{"country_id" => germany_id(), "zip_code" => "10115"}
            }
          }
        )

      # Should show error message and Weiter button should be disabled
      assert html =~ "Dieser Wohnsitz wurde bereits angegeben"
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Weiter/s
    end

    test "Weiter button is disabled on step 3 without valid zip code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      html = fill_step_2(lv)

      # Weiter should be disabled because zip code is empty
      assert html =~ "Postleitzahl"
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Weiter/s
    end
  end

  describe "birthday max constraint" do
    test "birthday input has max attribute set to 18 years before today", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      max_date = Date.utc_today() |> Date.shift(year: -18) |> to_string()
      assert html =~ ~s(max="#{max_date}")
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
end
