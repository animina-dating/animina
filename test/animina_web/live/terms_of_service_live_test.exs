defmodule AniminaWeb.TermsOfServiceLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /agb" do
    test "renders the AGB page with key content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/agb")

      assert html =~ "Allgemeine Geschäftsbedingungen"
      assert html =~ "Geltungsbereich"
      assert html =~ "Vertragsgegenstand"
      assert html =~ "Registrierung und Nutzerkonto"
      assert html =~ "Pflichten der Nutzer"
      assert html =~ "Inhalte und Moderation"
      assert html =~ "Nachrichten und Kommunikation"
      assert html =~ "Kontosperrung"
      assert html =~ "Recht auf Kontolöschung"
      assert html =~ "Datenschutz"
      assert html =~ "Haftungsbeschränkung"
      assert html =~ "Schlussbestimmungen"
    end

    test "renders shared layout with ANIMINA nav", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/agb")

      assert html =~ "ANIMINA"
    end

    test "links to privacy policy", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/agb")

      assert html =~ ~s(href="/datenschutz")
    end

    test "links to account deletion page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/agb")

      assert html =~ ~s(href="/settings/account")
    end
  end
end
