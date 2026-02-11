defmodule Animina.Accounts.ContactBlacklistTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.ContactBlacklist

  import Animina.AccountsFixtures

  describe "list_entries/1" do
    test "returns empty list for user with no entries" do
      user = user_fixture()
      assert ContactBlacklist.list_entries(user) == []
    end

    test "returns all entries for user" do
      user = user_fixture()
      {:ok, _entry1} = ContactBlacklist.add_entry(user, %{value: "first@example.com"})
      {:ok, _entry2} = ContactBlacklist.add_entry(user, %{value: "second@example.com"})

      entries = ContactBlacklist.list_entries(user)
      assert length(entries) == 2
      values = Enum.map(entries, & &1.value)
      assert "first@example.com" in values
      assert "second@example.com" in values
    end

    test "does not return entries from other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _} = ContactBlacklist.add_entry(user1, %{value: "test@example.com"})

      assert ContactBlacklist.list_entries(user2) == []
    end
  end

  describe "count_entries/1" do
    test "returns 0 for user with no entries" do
      user = user_fixture()
      assert ContactBlacklist.count_entries(user) == 0
    end

    test "returns correct count" do
      user = user_fixture()
      {:ok, _} = ContactBlacklist.add_entry(user, %{value: "a@example.com"})
      {:ok, _} = ContactBlacklist.add_entry(user, %{value: "b@example.com"})

      assert ContactBlacklist.count_entries(user) == 2
    end
  end

  describe "add_entry/2 with emails" do
    test "adds a valid email entry" do
      user = user_fixture()
      {:ok, entry} = ContactBlacklist.add_entry(user, %{value: "Test@Example.COM"})

      assert entry.entry_type == "email"
      assert entry.value == "test@example.com"
      assert entry.user_id == user.id
    end

    test "stores label correctly" do
      user = user_fixture()

      {:ok, entry} =
        ContactBlacklist.add_entry(user, %{value: "ex@example.com", label: "Ex-Husband email"})

      assert entry.label == "Ex-Husband email"
    end

    test "rejects invalid email" do
      user = user_fixture()
      {:error, changeset} = ContactBlacklist.add_entry(user, %{value: "not-an-email@"})

      assert errors_on(changeset)[:value]
    end

    test "rejects duplicate value for same user" do
      user = user_fixture()
      {:ok, _} = ContactBlacklist.add_entry(user, %{value: "same@example.com"})
      {:error, changeset} = ContactBlacklist.add_entry(user, %{value: "same@example.com"})

      assert errors_on(changeset)[:value]
    end

    test "allows same value across different users" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _} = ContactBlacklist.add_entry(user1, %{value: "shared@example.com"})
      {:ok, _} = ContactBlacklist.add_entry(user2, %{value: "shared@example.com"})
    end
  end

  describe "add_entry/2 with phone numbers" do
    test "adds a valid German mobile number" do
      user = user_fixture()
      {:ok, entry} = ContactBlacklist.add_entry(user, %{value: "0171 1234567"})

      assert entry.entry_type == "phone"
      assert entry.value == "+491711234567"
    end

    test "adds an international number" do
      user = user_fixture()
      {:ok, entry} = ContactBlacklist.add_entry(user, %{value: "+44 20 7946 0958"})

      assert entry.entry_type == "phone"
      assert String.starts_with?(entry.value, "+44")
    end

    test "adds a German landline number" do
      user = user_fixture()
      {:ok, entry} = ContactBlacklist.add_entry(user, %{value: "030 12345678"})

      assert entry.entry_type == "phone"
      assert entry.value == "+493012345678"
    end

    test "rejects invalid phone number" do
      user = user_fixture()
      {:error, changeset} = ContactBlacklist.add_entry(user, %{value: "123"})

      assert errors_on(changeset)[:value]
    end
  end

  describe "add_entry/2 limit enforcement" do
    test "enforces max-entry limit from feature flags" do
      user = user_fixture()

      # Set the limit to 10 for testing
      {:ok, setting} =
        Animina.FeatureFlags.get_or_create_flag_setting("system:contact_blacklist_max_entries", %{
          description: "test",
          settings: %{value: 10}
        })

      Animina.FeatureFlags.update_flag_setting(setting, %{settings: %{value: 10}})

      for i <- 1..10 do
        {:ok, _} = ContactBlacklist.add_entry(user, %{value: "user#{i}@example.com"})
      end

      assert {:error, :limit_reached} =
               ContactBlacklist.add_entry(user, %{value: "one-too-many@example.com"})
    end
  end

  describe "remove_entry/2" do
    test "removes own entry" do
      user = user_fixture()
      {:ok, entry} = ContactBlacklist.add_entry(user, %{value: "remove@example.com"})

      assert {:ok, _} = ContactBlacklist.remove_entry(user, entry.id)
      assert ContactBlacklist.list_entries(user) == []
    end

    test "returns error for non-existent entry" do
      user = user_fixture()
      assert {:error, :not_found} = ContactBlacklist.remove_entry(user, Ecto.UUID.generate())
    end

    test "cannot remove another user's entry" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, entry} = ContactBlacklist.add_entry(user1, %{value: "secret@example.com"})

      assert {:error, :not_found} = ContactBlacklist.remove_entry(user2, entry.id)
    end
  end

  describe "normalize_phone/1" do
    test "normalizes a German mobile number to E.164" do
      assert {:ok, "+491711234567"} = ContactBlacklist.normalize_phone("0171 1234567")
    end

    test "returns error for invalid phone" do
      assert {:error, _} = ContactBlacklist.normalize_phone("abc")
    end
  end
end
