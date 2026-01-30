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
  end

  describe "all emails use central sender config" do
    test "deliver_confirmation_pin uses configured sender name and email" do
      user = user_fixture()
      {:ok, email} = UserNotifier.deliver_confirmation_pin(user, "123456")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "deliver_password_reset_instructions uses configured sender name and email" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_password_reset_instructions(user, "https://example.com/reset")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "deliver_update_email_instructions uses configured sender name and email" do
      user = user_fixture()

      {:ok, email} =
        UserNotifier.deliver_update_email_instructions(user, "https://example.com/update")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end

    test "deliver_duplicate_registration_warning uses configured sender name and email" do
      {:ok, email} = UserNotifier.deliver_duplicate_registration_warning("test@example.com")

      assert email.from == {"ANIMINA 👫❤️", "noreply@animina.de"}
      assert email.headers["Auto-Submitted"] == "auto-generated"
      assert email.headers["Precedence"] == "bulk"
    end
  end
end
