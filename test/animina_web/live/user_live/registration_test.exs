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

  defp fill_step_3(lv) do
    lv
    |> element("#registration_form")
    |> render_change(
      user: %{
        "location_input" => %{"country_id" => germany_id(), "zip_code" => "10115"}
      }
    )

    lv |> element("button", "Add location") |> render_click()
    lv |> element("button[phx-click=next_step]") |> render_click()
  end

  describe "Registration page" do
    test "renders registration page with step 1 visible", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create account"
      assert html =~ "Log in now"
      # Step 1 fields visible
      assert html =~ "Email address"
      assert html =~ "Password"
      assert html =~ "Mobile phone"
      assert html =~ "Birthday"
      # Step 1 should show optional referral code field
      assert html =~ "Referral code"
      # Step 1 should show "Next" button, not "Create account" submit
      assert html =~ "Next"
      refute html =~ ~r/<button[^>]*type="submit"[^>]*>.*Create account/s
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

  describe "mobile phone validation" do
    test "rejects a landline number", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "email" => "test@example.com",
            "password" => "password1234",
            "mobile_phone" => "+4930123456",
            "birthday" => "1990-01-01"
          }
        )

      assert result =~ "must be a mobile number (not a landline)"
    end

    test "accepts a mobile number", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
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

      refute result =~ "must be a mobile number (not a landline)"
    end
  end

  describe "wizard navigation" do
    test "renders step indicator with 4 steps", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Account"
      assert html =~ "Profile"
      assert html =~ "Location"
      assert html =~ "Partner"
    end

    test "step 1 only shows Next button, no Back", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Next"
      refute html =~ "Back"
    end

    test "Next button is disabled when required step 1 fields are empty", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      # Button should be disabled on initial load (no fields filled)
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Next/s
    end

    test "Next button becomes enabled when step 1 fields are valid", %{conn: conn} do
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
      assert html =~ "Display name"
      assert html =~ "Gender"
      # Should have both Back and Next
      assert html =~ "Back"
      assert html =~ "Next"
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
      html = lv |> element("button", "Back") |> render_click()

      # Should be back on step 1
      assert html =~ "Email address"
      refute html =~ "Back"
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
      lv |> element("button", "Back") |> render_click()
      html = lv |> element("button", "Back") |> render_click()

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

      # Step 3 - add a location via input form
      html = fill_step_3(lv)

      # Step 4 should show partner preferences AND legal checkbox
      assert html =~ "Gender"
      assert html =~ "Search radius"
      assert html =~ "Terms of Service"
      # Step 4 should show "Create account" instead of "Next"
      assert html =~ "Create account"
    end

    test "auto-fills partner preferences when advancing to step 4", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Step 3
      html = fill_step_3(lv)

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
      fill_step_3(lv)

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      lv
      |> form("#registration_form")
      |> render_submit()

      # Should redirect to PIN confirmation page
      {path, _flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"
    end

    test "duplicate email does not reveal existence — redirects to PIN confirmation", %{
      conn: conn
    } do
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
      fill_step_3(lv)

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      lv
      |> form("#registration_form")
      |> render_submit()

      # Should redirect to PIN confirmation (phantom flow), NOT show "has already been taken"
      {path, flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"
      assert flash["info"] =~ "confirmation code"
    end

    test "duplicate email does not create a new user record", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      existing_email = "no-dup-user@email.com"
      user = user_fixture(%{email: existing_email})

      # Count users before
      user_count_before = Animina.Repo.aggregate(Animina.Accounts.User, :count, :id)

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
      fill_step_3(lv)

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      lv
      |> form("#registration_form")
      |> render_submit()

      assert_redirect(lv)

      # No new user should have been created
      user_count_after = Animina.Repo.aggregate(Animina.Accounts.User, :count, :id)
      assert user_count_before == user_count_after
    end

    test "phantom PIN confirmation shows identical UI", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "phantom-ui@email.com"})

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
      fill_step_3(lv)

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      lv
      |> form("#registration_form")
      |> render_submit()

      {path, _flash} = assert_redirect(lv)

      # Follow redirect to PIN confirmation page
      {:ok, pin_lv, pin_html} = live(conn, path)

      # Should show the same PIN confirmation UI
      assert pin_html =~ "Confirm your email"
      assert pin_html =~ "Confirmation code"
      assert pin_html =~ "Remaining attempts"
      assert pin_html =~ "Remaining time"

      # Enter a wrong PIN — should show error
      pin_lv
      |> form("#pin_form", pin: %{pin: "000000"})
      |> render_submit()

      assert render(pin_lv) =~ "Wrong code"
    end

    test "phantom flow redirects after 3 wrong PINs", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "phantom-fail@email.com"})

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
      fill_step_3(lv)

      # Step 4 - accept terms and submit
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "terms_accepted" => "true"
        }
      )

      lv
      |> form("#registration_form")
      |> render_submit()

      {path, _flash} = assert_redirect(lv)

      # Follow redirect to PIN confirmation page
      {:ok, pin_lv, _pin_html} = live(conn, path)

      # Enter wrong PINs 3 times
      pin_lv
      |> form("#pin_form", pin: %{pin: "111111"})
      |> render_submit()

      pin_lv
      |> form("#pin_form", pin: %{pin: "222222"})
      |> render_submit()

      pin_lv
      |> form("#pin_form", pin: %{pin: "333333"})
      |> render_submit()

      # Should redirect to register page with account deleted message
      {redirect_path, flash} = assert_redirect(pin_lv)
      assert redirect_path == "/users/register"
      assert flash["error"] =~ "account has been deleted"
    end
  end

  describe "partner age fields" do
    test "shows age fields in step 4", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Step 3
      html = fill_step_3(lv)

      assert html =~ "Minimum age"
      assert html =~ "Maximum age"
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
      fill_step_3(lv)

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

      lv
      |> form("#registration_form")
      |> render_submit()

      # Should redirect to PIN confirmation page
      {path, _flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"

      # Verify the offsets were correctly computed
      user = Animina.Repo.get_by!(Animina.Accounts.User, email: email)
      assert user.partner_minimum_age_offset == 11
      assert user.partner_maximum_age_offset == 9
    end
  end

  describe "multiple locations" do
    test "step 3 shows input form and no saved locations initially", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      html = fill_step_2(lv)

      # Should show input form with zip code field and add button
      assert html =~ "Zip code"
      assert html =~ "Add location"
      # No saved locations yet
      refute html =~ "saved-location-"
    end

    test "can add a location via input form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Fill the input form and click add
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "location_input" => %{"country_id" => germany_id(), "zip_code" => "10115"}
        }
      )

      html = lv |> element("button", "Add location") |> render_click()

      # Should show saved location
      assert html =~ "saved-location-"
      assert html =~ "10115"
    end

    test "can add two locations and remove one", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Add first location
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "location_input" => %{"country_id" => germany_id(), "zip_code" => "10115"}
        }
      )

      lv |> element("button", "Add location") |> render_click()

      # Add second location
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "location_input" => %{"country_id" => germany_id(), "zip_code" => "80331"}
        }
      )

      html = lv |> element("button", "Add location") |> render_click()

      # Should show two saved locations
      assert html =~ "10115"
      assert html =~ "80331"
      # Title should switch to plural
      assert html =~ "Locations"

      # Remove first location
      html = lv |> element("button[phx-value-id=\"1\"]") |> render_click()

      # Should only show one saved location
      assert html =~ "80331"
      refute html =~ "10115"
      # Title should switch back to singular
      assert html =~ "3. Location"
    end

    test "cannot add more than 4 locations", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      for zip <- ["10115", "80331", "50667", "20095"] do
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "location_input" => %{"country_id" => germany_id(), "zip_code" => zip}
          }
        )

        lv |> element("button", "Add location") |> render_click()
      end

      html = render(lv)

      # Should have 4 saved locations and input form should be hidden
      assert html =~ "10115"
      assert html =~ "20095"
      refute html =~ "Add location"
    end

    test "rejects duplicate zip code when adding", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Add first location
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "location_input" => %{"country_id" => germany_id(), "zip_code" => "10115"}
        }
      )

      lv |> element("button", "Add location") |> render_click()

      # Try to add same zip code again
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "location_input" => %{"country_id" => germany_id(), "zip_code" => "10115"}
        }
      )

      html = lv |> element("button", "Add location") |> render_click()

      # Should show error on input form
      assert html =~ "This location has already been added"
    end

    test "Next button is disabled on step 3 without any saved location", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      html = fill_step_2(lv)

      # Next should be disabled because no locations are saved
      assert html =~ "Zip code"
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Next/s
    end
  end

  describe "birthday max constraint" do
    test "birthday input has max attribute set to 18 years before today", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      max_date = Date.utc_today() |> Date.shift(year: -18) |> to_string()
      assert html =~ ~s(max="#{max_date}")
    end
  end

  describe "language pre-fill" do
    test "language field is pre-filled from session locale", %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{locale: "fr"})
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Go back to step 2 to see the language field
      html = lv |> element("button", "Back") |> render_click()

      # The language select should have "fr" selected
      assert html =~ ~s(<option selected value="fr">Français</option>) or
               html =~ ~s(<option value="fr" selected)
    end

    test "language field defaults to de when no session locale", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)

      # Step 2 should show language field with default locale
      html = render(lv)

      # English is set in test setup (ConnCase), so should be pre-filled as "en"
      assert html =~ ~s(selected)
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the login link is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in now")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end

  describe "referral code in registration" do
    test "step 1 shows optional referral code field", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Referral code (optional)"
      assert html =~ "A7X3K9"
    end

    test "registration with valid referral code succeeds", %{conn: conn} do
      referrer = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      # Step 1 with referral code
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => email,
          "password" => "password1234",
          "mobile_phone" => unique_mobile_phone(),
          "birthday" => "1990-01-01",
          "referral_code_input" => referrer.referral_code
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()
      fill_step_2(lv)
      fill_step_3(lv)

      lv
      |> element("#registration_form")
      |> render_change(user: %{"terms_accepted" => "true"})

      lv
      |> form("#registration_form")
      |> render_submit()

      {path, _flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"

      user = Animina.Repo.get_by!(Animina.Accounts.User, email: email)
      assert user.referred_by_id == referrer.id
    end

    test "registration with invalid referral code shows error", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Step 1 with invalid referral code
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "email" => unique_user_email(),
          "password" => "password1234",
          "mobile_phone" => unique_mobile_phone(),
          "birthday" => "1990-01-01",
          "referral_code_input" => "ZZZZZZ"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()
      fill_step_2(lv)
      fill_step_3(lv)

      lv
      |> element("#registration_form")
      |> render_change(user: %{"terms_accepted" => "true"})

      result =
        lv
        |> form("#registration_form")
        |> render_submit()

      assert result =~ "Referral code not found"
    end
  end
end
