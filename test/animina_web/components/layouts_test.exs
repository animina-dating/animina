defmodule AniminaWeb.LayoutsTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "navigation language picker" do
    test "renders globe icon in nav bar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      assert html =~ "hero-globe-alt"
      assert html =~ "language-menu-button"
      assert html =~ "language-dropdown"
    end

    test "language dropdown contains all 9 locales", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      for locale <- ~w(de en tr ru ar pl fr es uk) do
        assert html =~ ~s(name="locale" value="#{locale}")
      end
    end

    test "language dropdown shows native language names", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      assert html =~ "Deutsch"
      assert html =~ "English"
      assert html =~ "Français"
    end
  end

  describe "footer language picker" do
    test "renders language buttons in footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      # Footer should contain locale forms with abbreviations
      assert html =~ "footer-lang-de"
      assert html =~ "footer-lang-en"
      assert html =~ "footer-lang-uk"
    end
  end

  describe "authenticated user dropdown language picker" do
    setup :register_and_log_in_user

    test "user dropdown contains language settings link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      assert html =~ "user-dropdown"
      assert html =~ "/users/settings/language"
    end

    test "globe icon is hidden for authenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/demo")

      refute html =~ "language-menu-button"
      refute html =~ "language-dropdown"
    end
  end
end
