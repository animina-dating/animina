defmodule AniminaWeb.LanguageSwitchLive do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.User

  describe "Tests to ensure you can switch languages on the languages page" do
    test "A user can visit the language switcher page", %{conn: conn} do
      {:ok, _index_live, html} =
        conn
        |> live(~p"/language-switch")

      assert html =~ "Please select your preferred language"
    end

    test "A user can see the  languages in the language switcher page", %{conn: conn} do
      {:ok, _index_live, html} =
        conn
        |> live(~p"/language-switch")

      assert html =~ "🇩🇪  Deutsch"
      assert html =~ "🇺🇸 English"
    end

    test "A user can see switch languages in the language switcher page", %{conn: conn} do
      {:ok, index_live, html} =
        conn
        |> live(~p"/language-switch")

      assert html =~ "Please select your preferred language"

      index_live
      |> element("#switch-language-de")
      |> render_click()

      {:ok, index_live, html} =
        conn
        |> live(~p"/language-switch")

      refute html =~ "Please select your preferred language"
      assert html =~ "Bitte wählen Sie Ihre bevorzugte Sprache"
    end
  end
end
