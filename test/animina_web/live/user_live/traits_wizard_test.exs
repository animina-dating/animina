defmodule AniminaWeb.UserLive.TraitsWizardTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.TraitsFixtures

  setup :register_and_log_in_user

  describe "traits wizard" do
    setup do
      category1 = category_fixture(%{name: "Wizard Sports", position: 1, core: true})
      category2 = category_fixture(%{name: "Wizard Music", position: 2, core: true})
      flag1 = flag_fixture(%{name: "Soccer", emoji: "⚽", category_id: category1.id})
      flag2 = flag_fixture(%{name: "Rock", emoji: "🎸", category_id: category2.id})

      %{category1: category1, category2: category2, flag1: flag1, flag2: flag2}
    end

    test "step 1 renders About Me with categories and flags", %{
      conn: conn,
      category1: category1,
      flag1: flag1
    } do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")

      assert html =~ "About Me"
      assert html =~ category1.name
      assert html =~ flag1.name
    end

    test "next button navigates to step 2", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      html =
        view
        |> element("[phx-click=next_step]")
        |> render_click()

      assert html =~ "I Like in a Partner"
    end

    test "back button navigates from step 2 to step 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      view
      |> element("[phx-click=next_step]")
      |> render_click()

      html =
        view
        |> element("[phx-click=prev_step]")
        |> render_click()

      assert html =~ "About Me"
    end

    test "step 3 shows Deal Breakers with Finish link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 2
      view |> element("[phx-click=next_step]") |> render_click()
      # Navigate to step 3
      html = view |> element("[phx-click=next_step]") |> render_click()

      assert html =~ "Partner Deal Breakers"
      assert html =~ "Finish"
    end

    test "adding flag in step 1 assigns white color", %{conn: conn, flag1: flag1} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
        |> render_click()

      assert html =~ flag1.name
      # The flag should appear as selected (btn-neutral for white/step 1)
      assert has_element?(view, "button.btn-neutral[phx-value-flag-id=\"#{flag1.id}\"]")
    end

    test "adding flag in step 2 assigns green color as nice to have first", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 2
      view |> element("[phx-click=next_step]") |> render_click()

      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
        |> render_click()

      assert html =~ flag1.name
      # First click is now "nice to have" (soft) — btn-dash btn-success
      assert has_element?(view, "button.btn-dash.btn-success[phx-value-flag-id=\"#{flag1.id}\"]")
    end

    test "green flag 3-state cycle: off → nice to have → must have → off", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 2 (green)
      view |> element("[phx-click=next_step]") |> render_click()

      # Click 1: off → nice to have (btn-dash btn-success)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-dash.btn-success[phx-value-flag-id=\"#{flag1.id}\"]")

      # Click 2: nice to have → must have (btn-success, solid)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-success[phx-value-flag-id=\"#{flag1.id}\"]")
      refute has_element?(view, "button.btn-dash[phx-value-flag-id=\"#{flag1.id}\"]")

      # Click 3: must have → off (btn-outline)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag1.id}\"]")
    end

    test "red flag 3-state cycle: off → prefer not → dealbreaker → off", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 3 (red)
      view |> element("[phx-click=next_step]") |> render_click()
      view |> element("[phx-click=next_step]") |> render_click()

      # Click 1: off → prefer not (btn-dash btn-error)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-dash.btn-error[phx-value-flag-id=\"#{flag1.id}\"]")

      # Click 2: prefer not → dealbreaker (btn-error, solid)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-error[phx-value-flag-id=\"#{flag1.id}\"]")
      refute has_element?(view, "button.btn-dash[phx-value-flag-id=\"#{flag1.id}\"]")

      # Click 3: dealbreaker → off (btn-outline)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag1.id}\"]")
    end

    test "white flags use simple 2-state toggle (no intensity cycling)", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Click 1: unselected → selected (btn-neutral)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-neutral[phx-value-flag-id=\"#{flag1.id}\"]")

      # Click 2: selected → unselected (btn-outline) — no soft state
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag1.id}\"]")
    end

    test "step 2 shows intensity legend", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 2
      html = view |> element("[phx-click=next_step]") |> render_click()

      assert html =~ "must have"
      assert html =~ "nice to have"
    end

    test "step 3 shows intensity legend", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 3
      view |> element("[phx-click=next_step]") |> render_click()
      html = view |> element("[phx-click=next_step]") |> render_click()

      assert html =~ "deal breaker"
      assert html =~ "prefer not"
    end

    test "step 2 legend shows scoring impact labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits?step=green")

      assert html =~ "+10 pts"
      assert html =~ "Required"
    end

    test "step 3 legend shows scoring impact labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits?step=red")

      assert html =~ "-50 pts"
      assert html =~ "Excluded"
    end

    test "step 1 does not show scoring impact labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")

      refute html =~ "+10 pts"
      refute html =~ "-50 pts"
    end

    test "selecting a green flag on step 2 shows point badge on button", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits?step=green")

      # Click flag to select as nice to have (soft)
      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
        |> render_click()

      assert html =~ "+10 pts"

      # Click again to cycle to must have (hard) — shows "Required"
      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
        |> render_click()

      assert html =~ "Required"
    end

    test "selecting a red-hard flag on step 3 shows Excluded on button", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits?step=red")

      # Click flag to select as prefer not (soft)
      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
        |> render_click()

      assert html =~ "-50 pts"

      # Click again to cycle to deal breaker (hard) — shows "Excluded"
      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
        |> render_click()

      assert html =~ "Excluded"
    end

    test "green flags selected as red are disabled on step 2", %{conn: conn, flag1: flag1} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Go to step 3 (red) and select flag1 as red
      view |> element("[phx-click=goto_step][phx-value-step='3']") |> render_click()

      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      # Go back to step 2 (green) — flag1 should be disabled
      view |> element("[phx-click=goto_step][phx-value-step='2']") |> render_click()

      assert has_element?(
               view,
               "button.btn-disabled[phx-value-flag-id=\"#{flag1.id}\"]"
             )
    end

    test "red flags selected as green are disabled on step 3", %{conn: conn, flag1: flag1} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Go to step 2 (green) and select flag1 as green
      view |> element("[phx-click=goto_step][phx-value-step='2']") |> render_click()

      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      # Go to step 3 (red) — flag1 should be disabled
      view |> element("[phx-click=goto_step][phx-value-step='3']") |> render_click()

      assert has_element?(
               view,
               "button.btn-disabled[phx-value-flag-id=\"#{flag1.id}\"]"
             )
    end

    test "removing a green flag makes it available again on step 3", %{
      conn: conn,
      flag1: flag1
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Select flag1 as green (nice to have)
      view |> element("[phx-click=goto_step][phx-value-step='2']") |> render_click()

      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      # Confirm it's disabled on step 3
      view |> element("[phx-click=goto_step][phx-value-step='3']") |> render_click()
      assert has_element?(view, "button.btn-disabled[phx-value-flag-id=\"#{flag1.id}\"]")

      # Go back to step 2 and cycle flag1 through soft → hard → off
      view |> element("[phx-click=goto_step][phx-value-step='2']") |> render_click()
      # soft → hard
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      # hard → off
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      # Now on step 3 it should be available again
      view |> element("[phx-click=goto_step][phx-value-step='3']") |> render_click()
      refute has_element?(view, "button.btn-disabled[phx-value-flag-id=\"#{flag1.id}\"]")
      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag1.id}\"]")
    end

    test "finish link on step 3 navigates to settings", %{conn: conn, user: user} do
      user |> Ecto.Changeset.change(%{state: "normal"}) |> Animina.Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 3
      view |> element("[phx-click=next_step]") |> render_click()
      view |> element("[phx-click=next_step]") |> render_click()

      assert view
             |> element("a", "Finish")
             |> render_click()
             |> follow_redirect(conn, ~p"/my/settings/profile")
    end

    test "finish link on step 3 navigates to waitlist for waitlisted user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Navigate to step 3
      view |> element("[phx-click=next_step]") |> render_click()
      view |> element("[phx-click=next_step]") |> render_click()

      assert view
             |> element("a", "Finish")
             |> render_click()
             |> follow_redirect(conn, ~p"/my/waitlist")
    end

    test "clicking step dot navigates directly to that step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # From step 1, click step dot 3 to jump to step 3
      html =
        view
        |> element("[phx-click=goto_step][phx-value-step='3']")
        |> render_click()

      assert html =~ "Partner Deal Breakers"

      # From step 3, click step dot 1 to jump back to step 1
      html =
        view
        |> element("[phx-click=goto_step][phx-value-step='1']")
        |> render_click()

      assert html =~ "About Me"
    end

    test "clicking step dot 2 from step 1 navigates to step 2", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      html =
        view
        |> element("[phx-click=goto_step][phx-value-step='2']")
        |> render_click()

      assert html =~ "I Like in a Partner"
    end

    test "step dots display flag counts that update when toggling", %{
      conn: conn,
      flag1: flag1,
      flag2: flag2
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Initially no count badge is shown (count is 0)
      refute has_element?(view, "[phx-click=goto_step][phx-value-step='1'] .badge")

      # Select a white flag on step 1
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      # White flag count should now be 1
      assert has_element?(view, "[phx-click=goto_step][phx-value-step='1']", "1")

      # Select another white flag
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag2.id}\"]")
      |> render_click()

      # White flag count should now be 2
      assert has_element?(view, "[phx-click=goto_step][phx-value-step='1']", "2")
    end

    test "sensitive non-core categories appear in picker but flags hidden by default", %{
      conn: conn
    } do
      sens_cat =
        sensitive_category_fixture(%{
          name: "Wizard Sensitive",
          position: 99,
          picker_group: "sensitive"
        })

      _sens_flag = flag_fixture(%{name: "Secret Trait", emoji: "🔒", category_id: sens_cat.id})

      {:ok, view, html} = live(conn, ~p"/my/settings/profile/traits")

      # Category name should appear in the picker as a checkbox label
      assert has_element?(
               view,
               "label[phx-click=toggle_optin][phx-value-category-id=\"#{sens_cat.id}\"]"
             )

      # But the flag should NOT appear (not opted in)
      refute html =~ "Secret Trait"
    end

    test "toggling sensitive category in picker reveals its flags", %{conn: conn} do
      sens_cat =
        sensitive_category_fixture(%{
          name: "Wizard Private",
          position: 99,
          picker_group: "sensitive"
        })

      sens_flag = flag_fixture(%{name: "Private Trait", emoji: "🔐", category_id: sens_cat.id})

      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Click toggle_optin checkbox for this category in the picker
      html =
        view
        |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{sens_cat.id}\"]")
        |> render_click()

      # Flag should now be visible and selectable
      assert html =~ sens_flag.name
    end

    test "single-select category auto-replaces when selecting a different flag", %{conn: conn} do
      single_cat =
        single_select_category_fixture(%{name: "Wizard Have Children", position: 0, core: true})

      flag_a =
        flag_fixture(%{
          name: "I Have Children",
          emoji: "👨‍👩‍👧‍👦",
          category_id: single_cat.id,
          position: 1
        })

      flag_b =
        flag_fixture(%{
          name: "I Don't Have Children",
          emoji: "🚫👶",
          category_id: single_cat.id,
          position: 2
        })

      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Select flag_a — it should become active (btn-neutral)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag_a.id}\"]")
      |> render_click()

      # The button for flag_a should now have btn-neutral (selected)
      # and flag_b should still have btn-outline (unselected)
      assert has_element?(view, "button.btn-neutral[phx-value-flag-id=\"#{flag_a.id}\"]")
      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag_b.id}\"]")

      # Now select flag_b — flag_a should become inactive, flag_b active
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag_b.id}\"]")
      |> render_click()

      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag_a.id}\"]"),
             "flag_a should be btn-outline (deselected) after selecting flag_b"

      assert has_element?(view, "button.btn-neutral[phx-value-flag-id=\"#{flag_b.id}\"]"),
             "flag_b should be btn-neutral (selected) after clicking it"
    end

    test "delete all flags button removes all flags and reloads wizard", %{
      conn: conn,
      flag1: flag1,
      flag2: flag2
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Add some flags first
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag1.id}\"]")
      |> render_click()

      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag2.id}\"]")
      |> render_click()

      # Verify flags are selected
      assert has_element?(view, "button.btn-neutral[phx-value-flag-id=\"#{flag1.id}\"]")
      assert has_element?(view, "button.btn-neutral[phx-value-flag-id=\"#{flag2.id}\"]")

      # Click delete all flags
      html =
        view
        |> element("button[phx-click=delete_all_flags]")
        |> render_click()

      # Should show flash message and all flags should be unselected
      assert html =~ "All flags have been deleted"
      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag1.id}\"]")
      assert has_element?(view, "button.btn-outline[phx-value-flag-id=\"#{flag2.id}\"]")
    end
  end

  describe "URL step parameter" do
    setup do
      category = category_fixture(%{name: "URL Test Sports", position: 1, core: true})
      flag = flag_fixture(%{name: "Running", emoji: "🏃", category_id: category.id})
      %{category: category, flag: flag}
    end

    test "?step=white opens step 1", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits?step=white")
      assert html =~ "About Me"
    end

    test "?step=green opens step 2", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits?step=green")
      assert html =~ "I Like in a Partner"
    end

    test "?step=red opens step 3", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits?step=red")
      assert html =~ "Partner Deal Breakers"
    end

    test "no step param defaults to white (step 1)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")
      assert html =~ "About Me"
    end

    test "invalid step param defaults to white (step 1)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits?step=purple")
      assert html =~ "About Me"
    end

    test "next button updates URL to step=green", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      view |> element("[phx-click=next_step]") |> render_click()

      assert_patch(view, ~p"/my/settings/profile/traits?step=green")
    end

    test "step dot click updates URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      view |> element("[phx-click=goto_step][phx-value-step='3']") |> render_click()

      assert_patch(view, ~p"/my/settings/profile/traits?step=red")
    end
  end

  describe "trait name translations" do
    test "trait names are translated when locale is German", %{conn: conn, user: user} do
      Animina.Accounts.update_user_profile(user, %{language: "de"})
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")

      # Seeded "Character" category should appear as "Charakter"
      assert html =~ "Charakter"
      # Seeded "Honesty" flag should appear as "Ehrlichkeit"
      assert html =~ "Ehrlichkeit"
    end

    test "trait names show English when locale is English", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")

      # Seeded data should appear in English
      assert html =~ "Character"
      assert html =~ "Honesty"
    end
  end

  describe "category picker" do
    setup do
      core_cat = category_fixture(%{name: "Picker Core", position: 1, core: true})

      optin_cat =
        category_fixture(%{
          name: "Picker Lifestyle",
          position: 50,
          core: false,
          picker_group: "lifestyle"
        })

      sensitive_optin_cat =
        category_fixture(%{
          name: "Picker Sensitive",
          position: 51,
          core: false,
          picker_group: "sensitive",
          sensitive: true
        })

      core_flag = flag_fixture(%{name: "Core Flag", emoji: "🏠", category_id: core_cat.id})
      optin_flag = flag_fixture(%{name: "Lifestyle Flag", emoji: "🎯", category_id: optin_cat.id})

      sensitive_flag =
        flag_fixture(%{name: "Sensitive Flag", emoji: "🔒", category_id: sensitive_optin_cat.id})

      %{
        core_cat: core_cat,
        optin_cat: optin_cat,
        sensitive_optin_cat: sensitive_optin_cat,
        core_flag: core_flag,
        optin_flag: optin_flag,
        sensitive_flag: sensitive_flag
      }
    end

    test "core categories visible without opt-in", %{conn: conn, core_flag: core_flag} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")

      assert html =~ core_flag.name
    end

    test "non-core categories NOT visible by default", %{conn: conn, optin_flag: optin_flag} do
      {:ok, _view, html} = live(conn, ~p"/my/settings/profile/traits")

      refute html =~ optin_flag.name
    end

    test "category picker renders on all steps", %{conn: conn, optin_cat: optin_cat} do
      {:ok, view, html} = live(conn, ~p"/my/settings/profile/traits")

      # Step 1
      assert html =~ optin_cat.name

      # Step 2
      html = view |> element("[phx-click=next_step]") |> render_click()
      assert html =~ optin_cat.name

      # Step 3
      html = view |> element("[phx-click=next_step]") |> render_click()
      assert html =~ optin_cat.name
    end

    test "clicking picker checkbox reveals category's flags", %{
      conn: conn,
      optin_cat: optin_cat,
      optin_flag: optin_flag
    } do
      {:ok, view, html} = live(conn, ~p"/my/settings/profile/traits")

      refute html =~ optin_flag.name

      # Click the picker checkbox
      html =
        view
        |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{optin_cat.id}\"]")
        |> render_click()

      assert html =~ optin_flag.name
    end

    test "cannot uncheck category while it has active flags", %{
      conn: conn,
      optin_cat: optin_cat,
      optin_flag: optin_flag
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Opt in
      view
      |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{optin_cat.id}\"]")
      |> render_click()

      # Select a flag in the category
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{optin_flag.id}\"]")
      |> render_click()

      # Try to opt out — should be prevented, flag still visible
      html =
        view
        |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{optin_cat.id}\"]")
        |> render_click()

      assert html =~ optin_flag.name

      # Checkbox should be disabled
      assert has_element?(
               view,
               "label[phx-value-category-id=\"#{optin_cat.id}\"] input[disabled]"
             )
    end

    test "can uncheck category after removing all its flags", %{
      conn: conn,
      optin_cat: optin_cat,
      optin_flag: optin_flag
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Opt in and select a flag
      view
      |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{optin_cat.id}\"]")
      |> render_click()

      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{optin_flag.id}\"]")
      |> render_click()

      # Remove the flag (click again to deselect — white step is 2-state toggle)
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{optin_flag.id}\"]")
      |> render_click()

      # Now opt out should work
      html =
        view
        |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{optin_cat.id}\"]")
        |> render_click()

      refute html =~ optin_flag.name
    end

    test "picker state persists across step navigation", %{
      conn: conn,
      optin_cat: optin_cat,
      optin_flag: optin_flag
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Opt in on step 1
      view
      |> element("label[phx-click=toggle_optin][phx-value-category-id=\"#{optin_cat.id}\"]")
      |> render_click()

      # Navigate to step 2
      html = view |> element("[phx-click=next_step]") |> render_click()
      assert html =~ optin_flag.name

      # Navigate to step 3
      html = view |> element("[phx-click=next_step]") |> render_click()
      assert html =~ optin_flag.name

      # Navigate back to step 1
      html = view |> element("[phx-click=goto_step][phx-value-step='1']") |> render_click()
      assert html =~ optin_flag.name
    end

    test "sensitive categories in picker show lock indicator", %{
      conn: conn,
      sensitive_optin_cat: sensitive_optin_cat
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      assert has_element?(
               view,
               "label[phx-click=toggle_optin][phx-value-category-id=\"#{sensitive_optin_cat.id}\"]",
               "🔒"
             )
    end
  end

  describe "flag limit modal" do
    setup %{user: user} do
      category = category_fixture(%{name: "Limit Test Cat", position: 100, core: true})

      flags =
        for i <- 1..17 do
          flag_fixture(%{
            name: "Limit Flag #{i}",
            emoji: "🏷️",
            category_id: category.id,
            position: i
          })
        end

      # Pre-fill 16 white flags for the user
      for flag <- Enum.take(flags, 16) do
        {:ok, _} =
          Animina.Traits.add_user_flag(%{
            user_id: user.id,
            flag_id: flag.id,
            color: "white",
            intensity: "hard",
            position: flag.position
          })
      end

      %{category: category, flags: flags, seventeenth_flag: List.last(flags)}
    end

    test "modal appears when white flag limit is reached", %{
      conn: conn,
      seventeenth_flag: flag17
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Try to add the 17th white flag
      html =
        view
        |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag17.id}\"]")
        |> render_click()

      assert html =~ "Flag limit reached"
      # Verify the limit number is shown in the modal body
      assert html =~ "(16)"
    end

    test "modal is dismissable with OK button", %{
      conn: conn,
      seventeenth_flag: flag17
    } do
      {:ok, view, _html} = live(conn, ~p"/my/settings/profile/traits")

      # Trigger the modal
      view
      |> element("button[phx-click=toggle_flag][phx-value-flag-id=\"#{flag17.id}\"]")
      |> render_click()

      # Close the modal via the OK button
      html =
        view
        |> element("button[phx-click=close_flag_limit_modal]")
        |> render_click()

      refute html =~ "Flag limit reached"
    end
  end
end
