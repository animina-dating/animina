defmodule Animina.Accounts.EmailTemplatesTest do
  use ExUnit.Case, async: true

  alias Animina.Accounts.EmailTemplates

  @assigns_for_type %{
    confirmation_pin: [email: "test@example.com", display_name: "Test User", pin: "123456"],
    password_reset: [
      email: "test@example.com",
      display_name: "Test User",
      url: "https://example.com/reset/TOKEN"
    ],
    update_email: [
      email: "test@example.com",
      display_name: "Test User",
      url: "https://example.com/update/TOKEN"
    ],
    duplicate_registration: [
      email: "test@example.com",
      display_name: "Test User",
      attempted_at: "31. Januar 2026 um 14:00 Uhr"
    ],
    daily_report: [count: 3]
  }

  describe "render/3" do
    for locale <- ~w(de en tr ru ar pl fr es uk),
        type <-
          ~w(confirmation_pin password_reset update_email duplicate_registration daily_report)a do
      test "renders #{locale}/#{type} without errors and includes footer" do
        locale = unquote(locale)
        type = unquote(type)
        assigns = @assigns_for_type[type]

        {subject, body} = EmailTemplates.render(locale, type, assigns)

        assert is_binary(subject)
        assert is_binary(body)
        assert String.length(subject) > 0
        assert String.length(body) > 0

        # Every email must include the footer
        assert body =~ "Wintermeyer Consulting"
        assert body =~ "sw@wintermeyer-consulting.de"
        assert body =~ "https://wintermeyer-consulting.de"
      end
    end

    test "German confirmation_pin contains correct subject and variables" do
      {subject, body} =
        EmailTemplates.render("de", :confirmation_pin,
          email: "user@test.de",
          display_name: "Max",
          pin: "654321"
        )

      assert subject == "Ihr Bestätigungscode für ANIMINA"
      assert body =~ "Max"
      assert body =~ "654321"
    end

    test "English confirmation_pin contains correct subject and variables" do
      {subject, body} =
        EmailTemplates.render("en", :confirmation_pin,
          email: "user@test.com",
          display_name: "Jane",
          pin: "111222"
        )

      assert subject == "Your confirmation code for ANIMINA"
      assert body =~ "Jane"
      assert body =~ "111222"
    end

    test "German password_reset contains URL" do
      {subject, body} =
        EmailTemplates.render("de", :password_reset,
          email: "u@t.de",
          display_name: "Max",
          url: "https://animina.de/reset/abc"
        )

      assert subject == "Passwort zurücksetzen – ANIMINA"
      assert body =~ "https://animina.de/reset/abc"
      assert body =~ "Max"
    end

    test "English update_email contains URL" do
      {subject, body} =
        EmailTemplates.render("en", :update_email,
          email: "u@t.com",
          display_name: "Jane",
          url: "https://animina.de/update/xyz"
        )

      assert subject == "Update email instructions – ANIMINA"
      assert body =~ "https://animina.de/update/xyz"
    end

    test "German duplicate_registration contains email and display_name" do
      {subject, body} =
        EmailTemplates.render("de", :duplicate_registration,
          email: "dup@test.de",
          display_name: "Stefan",
          attempted_at: "31. Januar 2026 um 14:00 Uhr"
        )

      assert subject == "Sicherheitshinweis – ANIMINA"
      assert body =~ "dup@test.de"
      assert body =~ "Hallo Stefan,"
      assert body =~ "31. Januar 2026 um 14:00 Uhr"
    end

    test "German daily_report uses singular for count 1" do
      {subject, body} = EmailTemplates.render("de", :daily_report, count: 1)

      assert subject =~ "1"
      assert subject =~ "neuer Nutzer"
      assert body =~ "Nutzer hat"
    end

    test "German daily_report uses plural for count > 1" do
      {subject, body} = EmailTemplates.render("de", :daily_report, count: 5)

      assert subject =~ "5"
      assert subject =~ "neue Nutzer"
      assert body =~ "Nutzer haben"
    end

    test "falls back to German for unsupported locale" do
      {subject, _body} =
        EmailTemplates.render("xx", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "000000"
        )

      assert subject == "Ihr Bestätigungscode für ANIMINA"
    end

    test "falls back to German for nil locale" do
      {subject, _body} =
        EmailTemplates.render(nil, :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "000000"
        )

      assert subject == "Ihr Bestätigungscode für ANIMINA"
    end

    test "Turkish confirmation_pin has correct subject" do
      {subject, body} =
        EmailTemplates.render("tr", :confirmation_pin,
          email: "u@t.tr",
          display_name: "Ahmet",
          pin: "999888"
        )

      assert subject == "ANIMINA için onay kodunuz"
      assert body =~ "Ahmet"
      assert body =~ "999888"
    end

    test "French password_reset has correct subject" do
      {subject, _body} =
        EmailTemplates.render("fr", :password_reset,
          email: "u@t.fr",
          display_name: "Marie",
          url: "https://example.com"
        )

      assert subject == "Réinitialisation du mot de passe – ANIMINA"
    end

    test "Spanish duplicate_registration has correct subject" do
      {subject, _body} =
        EmailTemplates.render("es", :duplicate_registration,
          email: "u@t.es",
          display_name: "María",
          attempted_at: "31. Januar 2026 um 14:00 Uhr"
        )

      assert subject == "Aviso de seguridad – ANIMINA"
    end

    test "body does not contain separator lines" do
      {_subject, body} =
        EmailTemplates.render("en", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      refute body =~ "=============================="
    end

    test "German email ends with closing greeting before footer" do
      {_subject, body} =
        EmailTemplates.render("de", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      assert body =~ "Viele Grüße\n  Ihr ANIMINA Team"
    end

    test "English email ends with closing greeting before footer" do
      {_subject, body} =
        EmailTemplates.render("en", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      assert body =~ "Best regards,\n  Your ANIMINA Team"
    end

    test "closing greeting appears before signature delimiter" do
      {_subject, body} =
        EmailTemplates.render("de", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      [before_sig, _after_sig] = String.split(body, "\n-- \n", parts: 2)
      assert before_sig =~ "Viele Grüße"
    end

    test "German footer contains German text" do
      {_subject, body} =
        EmailTemplates.render("de", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      assert body =~ "ANIMINA ist ein kostenloser Dating-Service"
      assert body =~ "Wintermeyer Consulting"
    end

    test "English footer contains English text" do
      {_subject, body} =
        EmailTemplates.render("en", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      assert body =~ "ANIMINA is a free dating service"
      assert body =~ "Wintermeyer Consulting"
    end

    test "footer separator (-- ) appears in body" do
      {_subject, body} =
        EmailTemplates.render("en", :confirmation_pin,
          email: "a@b.com",
          display_name: "Test",
          pin: "123456"
        )

      assert body =~ "\n-- \n"
    end
  end
end
