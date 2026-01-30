defmodule Animina.Accounts.UserNotifierTest do
  use Animina.DataCase

  alias Animina.Accounts.UserNotifier

  import Animina.AccountsFixtures

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
