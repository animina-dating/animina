defmodule AniminaWeb.Admin.FeatureFlagsLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.FeatureFlags

  describe "Feature Flags admin page" do
    setup do
      admin = admin_fixture()

      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/feature-flags")
    end

    test "renders feature flags page for admin", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, html} = live(conn, ~p"/admin/feature-flags")

      assert html =~ "Feature Flags"
      assert html =~ "Photo Processing"
      assert html =~ "Ollama Photo Check"
      assert html =~ "Blacklist Check"
      assert has_element?(view, "[data-flag='photo_ollama_check']")
      assert has_element?(view, "[data-flag='photo_blacklist_check']")
    end

    test "can toggle a flag", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      # Initially enable the flag
      FunWithFlags.enable(:photo_ollama_check)
      {:ok, view, _} = live(conn, ~p"/admin/feature-flags")

      # Toggle the flag off
      view
      |> element("[data-flag='photo_ollama_check'] [phx-click='toggle-flag']")
      |> render_click()

      assert FeatureFlags.enabled?(:photo_ollama_check) == false

      # Toggle it back on
      view
      |> element("[data-flag='photo_ollama_check'] [phx-click='toggle-flag']")
      |> render_click()

      assert FeatureFlags.enabled?(:photo_ollama_check) == true
    end

    test "can open settings modal", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      view
      |> element("[data-flag='photo_ollama_check'] [phx-click='open-settings']")
      |> render_click()

      assert has_element?(view, "#settings-modal")
      assert render(view) =~ "Auto-approve"
      assert render(view) =~ "Delay"
    end

    test "can save settings", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      # Open settings modal
      view
      |> element("[data-flag='photo_ollama_check'] [phx-click='open-settings']")
      |> render_click()

      # Submit settings form
      view
      |> form("#settings-form", %{
        "settings" => %{
          "auto_approve" => "true",
          "delay_ms" => "500"
        }
      })
      |> render_submit()

      # Verify the settings were saved
      setting = FeatureFlags.get_flag_setting("photo_ollama_check")
      assert setting.settings["auto_approve"] == true
      assert setting.settings["delay_ms"] == 500
    end

    test "shows badges for configured settings", %{conn: conn, admin: admin} do
      # Update the existing setting with delay and auto_approve
      setting = FeatureFlags.get_flag_setting(:photo_ollama_check)

      if setting do
        FeatureFlags.update_flag_setting(setting, %{
          settings: %{delay_ms: 1000, auto_approve: true}
        })
      else
        FeatureFlags.create_flag_setting(%{
          flag_name: "photo_ollama_check",
          settings: %{delay_ms: 1000, auto_approve: true}
        })
      end

      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")

      assert html =~ "1000ms"
      assert html =~ "Auto"
    end

    test "can close settings modal", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      # Open modal
      view
      |> element("[data-flag='photo_ollama_check'] [phx-click='open-settings']")
      |> render_click()

      assert has_element?(view, "#settings-modal")

      # Close modal using the Cancel button (the one that says "Cancel")
      view
      |> element(".modal-action button.btn-ghost[phx-click='close-modal']")
      |> render_click()

      refute has_element?(view, "#settings-modal")
    end
  end
end
