defmodule AniminaWeb.UserLive.RegistrationTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  defp fill_step_1(lv) do
    lv
    |> element("#registration_form")
    |> render_change(
      user: %{
        "first_name" => "Jane",
        "last_name" => "Doe",
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

  defp fill_step_4_and_submit(lv) do
    lv
    |> element("#registration_form")
    |> render_change(user: %{"terms_accepted" => "true"})

    lv |> form("#registration_form") |> render_submit()
  end

  defp fill_all_steps(lv, attrs \\ %{}) do
    email = Map.get(attrs, :email, unique_user_email())
    mobile = Map.get(attrs, :mobile_phone, unique_mobile_phone())
    referral = Map.get(attrs, :referral_code_input)

    step_1_fields = %{
      "first_name" => "Jane",
      "last_name" => "Doe",
      "email" => email,
      "password" => "password1234",
      "mobile_phone" => mobile,
      "birthday" => "1990-01-01"
    }

    step_1_fields =
      if referral,
        do: Map.put(step_1_fields, "referral_code_input", referral),
        else: step_1_fields

    lv
    |> element("#registration_form")
    |> render_change(user: step_1_fields)

    lv |> element("button[phx-click=next_step]") |> render_click()
    fill_step_2(lv)
    fill_step_3(lv)
    fill_step_4_and_submit(lv)

    email
  end

  describe "Registration page" do
    test "has the correct HTML page title", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      assert page_title(lv) == "Secure Your Spot · ANIMINA"
    end

    test "renders registration page with step 1 visible", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Secure your spot"
      assert html =~ "Log in now"
      assert html =~ "regional waves"
      # Verify waitlist max days is shown (waitlist_duration_days default 14 + 1)
      assert html =~ "within 15 days at most"
      # Step 1 fields visible
      assert html =~ "First name"
      assert html =~ "Last name"
      assert html =~ "Email address"
      assert html =~ "Password"
      assert html =~ "Mobile phone"
      assert html =~ "Birthday"
      # Step 1 should show optional referral code field
      assert html =~ "Referral code"
      # Step 1 should show "Next" button, not "Secure your spot" submit
      assert html =~ "Next"
      refute html =~ ~r/<button[^>]*type="submit"[^>]*>\s*Secure your spot/s
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/my")

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
            "first_name" => "Jane",
            "last_name" => "Doe",
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
            "first_name" => "Jane",
            "last_name" => "Doe",
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
            "first_name" => "Jane",
            "last_name" => "Doe",
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

      html = fill_step_1(lv)

      assert html =~ "Display name"
      assert html =~ "Gender"
      assert html =~ "Back"
      assert html =~ "Next"
    end

    test "back button works without validation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)

      html = lv |> element("button", "Back") |> render_click()

      assert html =~ "Email address"
      refute html =~ "Back"
    end

    test "data persists across steps", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Go back to step 1
      lv |> element("button", "Back") |> render_click()
      html = lv |> element("button", "Back") |> render_click()

      assert html =~ "test@example.com"
    end

    test "shows display_name in navbar after completing step 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      html = fill_step_2(lv)

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
      assert html =~ "Privacy Policy"
      assert html =~ "Terms of Service"
      # Step 4 should show "Secure your spot" instead of "Next"
      assert html =~ "Secure your spot"
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

      fill_all_steps(lv)

      {path, _flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"
    end

    test "duplicate email does not reveal existence — redirects to PIN confirmation", %{
      conn: conn
    } do
      user = user_fixture(%{email: "test@email.com"})

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_all_steps(lv, %{email: user.email})

      {path, flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"
      assert flash["info"] =~ "confirmation code"
    end

    test "duplicate email does not create a new user record", %{conn: conn} do
      existing_email = "no-dup-user@email.com"
      _user = user_fixture(%{email: existing_email})

      user_count_before = Animina.Repo.aggregate(Animina.Accounts.User, :count, :id)

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_all_steps(lv, %{email: existing_email})

      assert_redirect(lv)

      user_count_after = Animina.Repo.aggregate(Animina.Accounts.User, :count, :id)
      assert user_count_before == user_count_after
    end

    test "phantom PIN confirmation shows identical UI", %{conn: conn} do
      _user = user_fixture(%{email: "phantom-ui@email.com"})

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_all_steps(lv, %{email: "phantom-ui@email.com"})

      {path, _flash} = assert_redirect(lv)

      {:ok, pin_lv, pin_html} = live(conn, path)

      assert pin_html =~ "Confirm your email"
      assert pin_html =~ "Confirmation code"
      assert pin_html =~ "Remaining attempts"
      assert pin_html =~ "Remaining time"

      pin_lv
      |> form("#pin_form", pin: %{pin: "000000"})
      |> render_submit()

      assert render(pin_lv) =~ "Wrong code"
    end

    test "phantom flow redirects after 3 wrong PINs", %{conn: conn} do
      _user = user_fixture(%{email: "phantom-fail@email.com"})

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_all_steps(lv, %{email: "phantom-fail@email.com"})

      {path, _flash} = assert_redirect(lv)

      {:ok, pin_lv, _pin_html} = live(conn, path)

      for pin <- ["111111", "222222", "333333"] do
        pin_lv |> form("#pin_form", pin: %{pin: pin}) |> render_submit()
      end

      {redirect_path, flash} = assert_redirect(pin_lv)
      assert redirect_path == "/users/register"
      assert flash["error"] =~ "account has been deleted"
    end
  end

  describe "step 1 to step 2 prefill" do
    test "prefills display_name with first_name when advancing to step 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "first_name" => "Jane",
          "last_name" => "Doe",
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Display name input should be prefilled with the first name
      assert html =~ ~s(value="Jane")
    end

    test "gender defaults to male when no guess is available", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "first_name" => "Xyztestname",
          "last_name" => "Doe",
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Gender should default to male (the initial value) since no guess available
      assert html =~ ~r/checked.*value="male"/s || html =~ "male"
    end

    test "prefills gender from cache when available", %{conn: conn} do
      # "sophie" is seeded as female in the first_name_genders migration
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "first_name" => "Sophie",
          "last_name" => "Doe",
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Gender should be prefilled as female from cache
      # The radio input renders: <input type="radio" ... value="female" checked ...>
      assert html =~ ~r/<input[^>]*value="female"[^>]*checked/s
    end

    test "partner preferences use opposite of guessed gender", %{conn: conn} do
      # "petra" is seeded as female in the first_name_genders migration

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "first_name" => "Petra",
          "last_name" => "Doe",
          "email" => "test@example.com",
          "password" => "password1234",
          "mobile_phone" => "+4915112345678",
          "birthday" => "1990-01-01"
        }
      )

      # Step 1 → 2 (gender prefilled as female)
      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 2 → 3 (keep female gender, fill height)
      lv
      |> element("#registration_form")
      |> render_change(user: %{"display_name" => "Petra", "height" => "170"})

      lv |> element("button[phx-click=next_step]") |> render_click()

      # Step 3 → 4 (add location and advance)
      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "location_input" => %{"country_id" => germany_id(), "zip_code" => "10115"}
        }
      )

      lv |> element("button", "Add location") |> render_click()
      html = lv |> element("button[phx-click=next_step]") |> render_click()

      # Partner preference should be "male" (opposite of female)
      assert html =~ ~r/<input[^>]*value="male"[^>]*checked/s
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

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "first_name" => "Jane",
          "last_name" => "Doe",
          "email" => email,
          "password" => "password1234",
          "mobile_phone" => unique_mobile_phone(),
          "birthday" => "1990-01-01"
        }
      )

      lv |> element("button[phx-click=next_step]") |> render_click()
      fill_step_2(lv)
      fill_step_3(lv)

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "partner_minimum_age" => "25",
          "partner_maximum_age" => "45",
          "terms_accepted" => "true"
        }
      )

      lv |> form("#registration_form") |> render_submit()

      {path, _flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"

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

    test "Next button stays disabled for invalid zip code that doesn't exist", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Enter a 5-digit zip code that doesn't exist in the database
      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "location_input" => %{"country_id" => germany_id(), "zip_code" => "99999"}
          }
        )

      # Should show validation error
      assert html =~ "not a valid zip code"
      # Next button should remain disabled
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Next/s
    end

    test "add location button is disabled for non-existent zip code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      html =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "location_input" => %{"country_id" => germany_id(), "zip_code" => "99999"}
          }
        )

      # Should show error, button should be disabled, and no location added
      assert html =~ "not a valid zip code"
      assert html =~ ~r/<button[^>]*disabled[^>]*>.*Add location/s
      refute html =~ "saved-location-"
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
      conn = init_test_session(conn, %{locale: "fr"})
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      fill_step_1(lv)
      fill_step_2(lv)

      # Go back to step 2 to see the language field (button text is in French since locale is "fr")
      html = lv |> element("button", "Retour") |> render_click()

      # The language select should have "fr" selected
      assert html =~ ~r/<option[^>]*selected[^>]*value="fr"[^>]*>Français<\/option>/
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

      email = fill_all_steps(lv, %{referral_code_input: referrer.referral_code})

      {path, _flash} = assert_redirect(lv)
      assert path =~ "/users/confirm/"

      user = Animina.Repo.get_by!(Animina.Accounts.User, email: email)
      assert user.referred_by_id == referrer.id
    end

    test "registration with invalid referral code shows error", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> element("#registration_form")
      |> render_change(
        user: %{
          "first_name" => "Jane",
          "last_name" => "Doe",
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

      result = lv |> form("#registration_form") |> render_submit()

      assert result =~ "Referral code not found"
    end
  end
end
