defmodule Animina.Accounts.UserNotifierTest do
  use Animina.DataCase

  alias Animina.Accounts.UserNotifier

  import Animina.AccountsFixtures

  describe "deliver_daily_new_users_report/2" do
    test "uses configured sender name and email" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(3, {"Stefan", "stefan@example.com"})

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "sends to the given recipient email" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(5, {"Stefan", "stefan@example.com"})

      assert email.to == [{"", "stefan@example.com"}]
    end

    test "includes count in subject" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(7, {"Stefan", "stefan@example.com"})

      assert email.subject =~ "7"
    end

    test "includes count in body" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(3, {"Stefan", "stefan@example.com"})

      assert email.text_body =~ "3"
    end

    test "includes debug link in body" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(3, {"Stefan", "stefan@example.com"})

      assert email.text_body =~ "https://animina.de/debug"
    end

    test "uses singular for count of 1" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(1, {"Stefan", "stefan@example.com"})

      assert email.text_body =~ "Nutzer hat"
    end

    test "uses plural for count greater than 1" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(5, {"Stefan", "stefan@example.com"})

      assert email.text_body =~ "Nutzer haben"
    end

    test "always uses German locale" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(2, {"Stefan", "stefan@example.com"})

      assert email.subject =~ "ANIMINA:"
      assert email.subject =~ "Nutzer"
    end

    test "includes footer in body" do
      {:ok, email} =
        UserNotifier.deliver_daily_new_users_report(3, {"Stefan", "stefan@example.com"})

      assert email.text_body =~ "Wintermeyer Consulting"
      assert email.text_body =~ "sw@wintermeyer-consulting.de"
    end
  end

  describe "deliver_registration_spike_alert/2" do
    @spike_stats %{
      today_count: 10,
      daily_average: 3.0,
      threshold: 4.5,
      spike_factor: 3.3,
      yesterday_count: 4,
      hourly_breakdown: [{9, 5}, {10, 5}]
    }

    test "includes debug link in body" do
      {:ok, email} =
        UserNotifier.deliver_registration_spike_alert(
          @spike_stats,
          {"Stefan", "stefan@example.com"}
        )

      assert email.text_body =~ "https://animina.de/debug"
    end
  end

  describe "deliver_confirmation_pin/2" do
    test "uses configured sender name and email" do
      user = user_fixture()
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "includes the PIN in the body" do
      user = user_fixture()
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "654321")

      assert email.text_body =~ "654321"
    end

    test "includes user display_name in the body" do
      user = user_fixture()
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.text_body =~ user.display_name
    end

    test "uses German subject when user language is de" do
      user = user_fixture(%{language: "de"})
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.subject == "Dein Bestätigungscode für ANIMINA"
    end

    test "uses English subject when user language is en" do
      user = user_fixture(%{language: "en"})
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.subject == "Your confirmation code for ANIMINA"
    end

    test "uses Turkish subject when user language is tr" do
      user = user_fixture(%{language: "tr"})
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.subject == "ANIMINA için onay kodunuz"
    end

    test "includes footer in body" do
      user = user_fixture()
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.text_body =~ "Wintermeyer Consulting"
      assert email.text_body =~ "sw@wintermeyer-consulting.de"
    end
  end

  describe "deliver_password_reset_instructions/2" do
    test "uses configured sender name and email" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_password_reset_instructions(user, "https://example.com/reset")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "includes the URL in the body" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_password_reset_instructions(user, "https://example.com/reset/TOKEN")

      assert email.text_body =~ "https://example.com/reset/TOKEN"
    end

    test "uses German subject when user language is de" do
      user = user_fixture(%{language: "de"})

      {:ok, email} =
        UserNotifier.deliver_password_reset_instructions(user, "https://example.com/reset")

      assert email.subject == "Passwort zurücksetzen – ANIMINA"
    end

    test "uses French subject when user language is fr" do
      user = user_fixture(%{language: "fr"})

      {:ok, email} =
        UserNotifier.deliver_password_reset_instructions(user, "https://example.com/reset")

      assert email.subject == "Réinitialisation du mot de passe – ANIMINA"
    end

    test "includes footer in body" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_password_reset_instructions(user, "https://example.com/reset")

      assert email.text_body =~ "Wintermeyer Consulting"
      assert email.text_body =~ "sw@wintermeyer-consulting.de"
    end
  end

  describe "deliver_update_email_instructions/2" do
    test "uses configured sender name and email" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_update_email_instructions(user, "https://example.com/update")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "includes the URL in the body" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_update_email_instructions(user, "https://example.com/update/TOKEN")

      assert email.text_body =~ "https://example.com/update/TOKEN"
    end

    test "uses Spanish subject when user language is es" do
      user = user_fixture(%{language: "es"})

      {:ok, email} =
        UserNotifier.deliver_update_email_instructions(user, "https://example.com/update")

      assert email.subject == "Instrucciones para cambiar el correo electrónico – ANIMINA"
    end

    test "includes footer in body" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_update_email_instructions(user, "https://example.com/update")

      assert email.text_body =~ "Wintermeyer Consulting"
      assert email.text_body =~ "sw@wintermeyer-consulting.de"
    end
  end

  describe "deliver_duplicate_registration_warning/1" do
    test "uses configured sender name and email" do
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning("test@example.com")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "includes the email address in the body" do
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning("existing@example.com")

      assert email.text_body =~ "existing@example.com"
    end

    test "uses German for unknown email addresses" do
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning("unknown@example.com")

      assert email.subject == "Sicherheitshinweis – ANIMINA"
    end

    test "uses user's language when user exists" do
      user = user_fixture(%{language: "en"})
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning(user.email)

      assert email.subject == "Security notice – ANIMINA"
    end

    test "includes user's display_name in greeting when user exists" do
      user = user_fixture(%{language: "de"})
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning(user.email)

      assert email.text_body =~ "Hallo #{user.display_name},"
    end

    test "includes German-formatted timestamp in body" do
      user = user_fixture(%{language: "de"})
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning(user.email)

      assert email.text_body =~ "Uhr"
      assert email.text_body =~ ~r/\d{1,2}\. \w+ \d{4} um \d{2}:\d{2} Uhr/
    end

    test "includes footer in body" do
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning("test@example.com")

      assert email.text_body =~ "Wintermeyer Consulting"
      assert email.text_body =~ "sw@wintermeyer-consulting.de"
    end
  end
end
