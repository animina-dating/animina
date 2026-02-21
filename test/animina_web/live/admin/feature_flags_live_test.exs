defmodule AniminaWeb.Admin.FeatureFlagsLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias Animina.FeatureFlags

  describe "Feature Flags hub page" do
    setup do
      admin = admin_fixture()

      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/flags")
    end

    test "renders hub with 2 cards", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/flags")

      assert html =~ "Feature Flags"
      assert html =~ "AI / Ollama"
      assert html =~ "System Settings"
    end

    test "canonical /admin/flags path shows hub", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/flags")

      assert html =~ "Feature Flags"
      assert html =~ "AI / Ollama"
    end
  end

  describe "AI/Ollama subpage" do
    setup do
      admin = admin_fixture()

      %{admin: admin}
    end

    test "renders AI settings page with breadcrumbs", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/flags/ai")

      assert html =~ "AI / Ollama"
      assert html =~ "Ollama Photo Check"
      assert html =~ "Feature Flags"
    end

    test "can toggle an ollama flag", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")

      FunWithFlags.enable(:photo_ollama_check)
      {:ok, view, _} = live(conn, ~p"/admin/flags/ai")

      view
      |> element("[data-setting='photo_ollama_check'] [phx-click='toggle-ollama-flag']")
      |> render_click()

      assert FeatureFlags.enabled?(:photo_ollama_check) == false
    end

    test "can open and close ollama settings modal", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/flags/ai")

      view
      |> element("[data-setting='photo_ollama_check'] [phx-click='open-ollama-setting']")
      |> render_click()

      assert has_element?(view, "#ollama-setting-modal")
      assert render(view) =~ "Auto-approve"

      view
      |> element(".modal-action button.btn-ghost[phx-click='close-ollama-modal']")
      |> render_click()

      refute has_element?(view, "#ollama-setting-modal")
    end

    test "can save ollama settings", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/flags/ai")

      view
      |> element("[data-setting='photo_ollama_check'] [phx-click='open-ollama-setting']")
      |> render_click()

      view
      |> form("#ollama-setting-form", %{
        "ollama_setting" => %{
          "auto_approve" => "true",
          "delay_ms" => "500"
        }
      })
      |> render_submit()

      setting = FeatureFlags.get_flag_setting("photo_ollama_check")
      assert setting.settings["auto_approve"] == true
      assert setting.settings["delay_ms"] == 500
    end
  end

  describe "System subpage" do
    setup do
      admin = admin_fixture()

      %{admin: admin}
    end

    test "renders system settings with breadcrumbs", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/flags/system")

      assert html =~ "System Settings"
      assert html =~ "Referral Threshold"
      assert html =~ "Feature Flags"
    end

    test "can open and save a system setting", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/flags/system")

      view
      |> element("[data-setting='referral_threshold'] [phx-click='open-system-setting']")
      |> render_click()

      assert has_element?(view, "#system-setting-modal")

      view
      |> form("#system-setting-form", %{
        "system_setting" => %{"value" => "5"}
      })
      |> render_submit()

      assert FeatureFlags.get_system_setting_value(:referral_threshold, 3) == 5
    end
  end
end
