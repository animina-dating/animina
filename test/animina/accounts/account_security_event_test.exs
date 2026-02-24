defmodule Animina.Accounts.AccountSecurityEventTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts
  alias Animina.Accounts.AccountSecurityEvent

  import Animina.AccountsFixtures

  describe "AccountSecurityEvent.build/3" do
    test "generates undo and confirm tokens" do
      {undo_token, confirm_token, event} =
        AccountSecurityEvent.build(Ecto.UUID.generate(), "email_change", %{
          old_email: "old@example.com",
          old_value: "old@example.com",
          new_value: "new@example.com"
        })

      assert is_binary(undo_token)
      assert is_binary(confirm_token)
      assert undo_token != confirm_token
      assert event.event_type == "email_change"
      assert event.old_email == "old@example.com"
      assert event.old_value == "old@example.com"
      assert event.new_value == "new@example.com"
      assert event.undo_token_hash
      assert event.confirm_token_hash
      assert event.expires_at
    end

    test "expires_at is ~48 hours in the future" do
      {_, _, event} = AccountSecurityEvent.build(Ecto.UUID.generate(), "password_change")

      diff = DateTime.diff(event.expires_at, DateTime.utc_now(:second), :hour)
      assert diff >= 47 and diff <= 48
    end
  end

  describe "verify_undo_token_query/1" do
    test "finds event by valid undo token" do
      user = user_fixture()

      {undo_token, _confirm_token, event} =
        AccountSecurityEvent.build(user.id, "email_change", %{old_email: user.email})

      Animina.Repo.insert!(event)

      assert {:ok, query} = AccountSecurityEvent.verify_undo_token_query(undo_token)
      assert Animina.Repo.one(query)
    end

    test "returns error for invalid base64" do
      assert :error = AccountSecurityEvent.verify_undo_token_query("not-valid-base64!!!")
    end

    test "does not find resolved events" do
      user = user_fixture()

      {undo_token, _confirm_token, event} =
        AccountSecurityEvent.build(user.id, "email_change")

      event = Animina.Repo.insert!(event)

      event
      |> Ecto.Changeset.change(resolved_at: DateTime.utc_now(:second), resolution: "undone")
      |> Animina.Repo.update!()

      {:ok, query} = AccountSecurityEvent.verify_undo_token_query(undo_token)
      refute Animina.Repo.one(query)
    end

    test "does not find expired events" do
      user = user_fixture()

      {undo_token, _confirm_token, event} =
        AccountSecurityEvent.build(user.id, "email_change")

      event = %{event | expires_at: DateTime.add(DateTime.utc_now(:second), -1, :hour)}
      Animina.Repo.insert!(event)

      {:ok, query} = AccountSecurityEvent.verify_undo_token_query(undo_token)
      refute Animina.Repo.one(query)
    end
  end

  describe "verify_confirm_token_query/1" do
    test "finds event by valid confirm token" do
      user = user_fixture()

      {_undo_token, confirm_token, event} =
        AccountSecurityEvent.build(user.id, "password_change")

      Animina.Repo.insert!(event)

      assert {:ok, query} = AccountSecurityEvent.verify_confirm_token_query(confirm_token)
      assert Animina.Repo.one(query)
    end
  end

  describe "cooldown enforcement" do
    test "has_active_security_cooldown? returns true after event creation" do
      user = user_fixture()
      {_, _, event} = AccountSecurityEvent.build(user.id, "email_change")
      Animina.Repo.insert!(event)

      assert Accounts.has_active_security_cooldown?(user.id)
    end

    test "has_active_security_cooldown? returns false with no events" do
      user = user_fixture()
      refute Accounts.has_active_security_cooldown?(user.id)
    end

    test "has_active_security_cooldown? returns false after event is resolved" do
      user = user_fixture()
      {_, _, event} = AccountSecurityEvent.build(user.id, "email_change")
      event = Animina.Repo.insert!(event)

      event
      |> Ecto.Changeset.change(resolved_at: DateTime.utc_now(:second), resolution: "confirmed")
      |> Animina.Repo.update!()

      refute Accounts.has_active_security_cooldown?(user.id)
    end

    test "check_no_active_cooldown returns error when cooldown active" do
      user = user_fixture()
      {_, _, event} = AccountSecurityEvent.build(user.id, "email_change")
      Animina.Repo.insert!(event)

      assert {:error, :cooldown_active} = Accounts.check_no_active_cooldown(user.id)
    end

    test "update_user_password is blocked by cooldown" do
      user = user_fixture()
      {_, _, event} = AccountSecurityEvent.build(user.id, "email_change")
      Animina.Repo.insert!(event)

      assert {:error, :cooldown_active} =
               Accounts.update_user_password(user, %{password: "new_valid_password_123"})
    end
  end

  describe "undo_security_event/1" do
    test "undoes an email change" do
      user = user_fixture()
      old_email = user.email
      new_email = unique_user_email()

      # Simulate email change
      user
      |> Ecto.Changeset.change(email: new_email)
      |> Animina.Repo.update!()

      {:ok, security_info} =
        Accounts.create_security_event_for_email_change(user, old_email, new_email)

      # Undo the change
      assert {:ok, _event} = Accounts.undo_security_event(security_info.undo_token)

      # Email should be reverted
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email == old_email
    end

    test "undoes a password change" do
      user = user_fixture()
      old_hash = user.hashed_password

      # Change the password
      user
      |> Ecto.Changeset.change(hashed_password: "new_fake_hash")
      |> Animina.Repo.update!()

      {:ok, security_info} =
        Accounts.create_security_event_for_password_change(user, old_hash)

      # Undo the change
      assert {:ok, _event} = Accounts.undo_security_event(security_info.undo_token)

      # Password hash should be restored
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.hashed_password == old_hash
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} =
               Accounts.undo_security_event("totally_invalid_token")
    end

    test "returns error for already resolved event" do
      user = user_fixture()

      {:ok, security_info} =
        Accounts.create_security_event_for_email_change(user, user.email, "new@test.com")

      # Resolve it first
      {:ok, _} = Accounts.confirm_security_event(security_info.confirm_token)

      # Try to undo — should fail
      assert {:error, :invalid_token} =
               Accounts.undo_security_event(security_info.undo_token)
    end
  end

  describe "confirm_security_event/1" do
    test "confirms a security event and clears cooldown" do
      user = user_fixture()

      {:ok, security_info} =
        Accounts.create_security_event_for_email_change(user, user.email, "new@test.com")

      assert Accounts.has_active_security_cooldown?(user.id)

      assert {:ok, event} = Accounts.confirm_security_event(security_info.confirm_token)
      assert event.resolution == "confirmed"
      assert event.resolved_at

      refute Accounts.has_active_security_cooldown?(user.id)
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} =
               Accounts.confirm_security_event("totally_invalid_token")
    end
  end
end
