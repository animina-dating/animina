defmodule Animina.Accounts.UserPasskeyTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts
  alias Animina.Accounts.UserPasskey

  import Animina.AccountsFixtures

  @valid_credential_id :crypto.strong_rand_bytes(32)
  @valid_cose_key %{
    1 => 2,
    3 => -7,
    -1 => 1,
    -2 => :crypto.strong_rand_bytes(32),
    -3 => :crypto.strong_rand_bytes(32)
  }

  describe "UserPasskey schema" do
    test "changeset with valid attributes" do
      user = user_fixture()

      changeset =
        UserPasskey.changeset(%UserPasskey{}, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key,
          user_id: user.id,
          label: "My MacBook"
        })

      assert changeset.valid?
    end

    test "changeset requires credential_id, public_key, and user_id" do
      changeset = UserPasskey.changeset(%UserPasskey{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors[:credential_id]
      assert "can't be blank" in errors[:public_key]
      assert "can't be blank" in errors[:user_id]
    end

    test "changeset validates label length" do
      user = user_fixture()

      changeset =
        UserPasskey.changeset(%UserPasskey{}, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key,
          user_id: user.id,
          label: String.duplicate("a", 101)
        })

      errors = errors_on(changeset)
      assert "should be at most 100 character(s)" in errors[:label]
    end
  end

  describe "CoseKeyType" do
    test "round-trips a COSE key through the database" do
      user = user_fixture()

      {:ok, passkey} =
        Accounts.create_user_passkey(user, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key
        })

      loaded = Animina.Repo.get!(UserPasskey, passkey.id)
      assert loaded.public_key == @valid_cose_key
    end
  end

  describe "list_user_passkeys/1" do
    test "returns empty list when user has no passkeys" do
      user = user_fixture()
      assert Accounts.list_user_passkeys(user) == []
    end

    test "returns all passkeys for a user" do
      user = user_fixture()

      {:ok, _pk1} =
        Accounts.create_user_passkey(user, %{
          credential_id: :crypto.strong_rand_bytes(32),
          public_key: @valid_cose_key,
          label: "Key 1"
        })

      {:ok, _pk2} =
        Accounts.create_user_passkey(user, %{
          credential_id: :crypto.strong_rand_bytes(32),
          public_key: @valid_cose_key,
          label: "Key 2"
        })

      passkeys = Accounts.list_user_passkeys(user)
      assert length(passkeys) == 2
    end

    test "does not return passkeys from other users" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} =
        Accounts.create_user_passkey(user1, %{
          credential_id: :crypto.strong_rand_bytes(32),
          public_key: @valid_cose_key
        })

      assert Accounts.list_user_passkeys(user2) == []
    end
  end

  describe "create_user_passkey/2" do
    test "creates a passkey with valid attributes" do
      user = user_fixture()

      {:ok, passkey} =
        Accounts.create_user_passkey(user, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key,
          label: "Test Key"
        })

      assert passkey.credential_id == @valid_credential_id
      assert passkey.public_key == @valid_cose_key
      assert passkey.label == "Test Key"
      assert passkey.sign_count == 0
      assert passkey.user_id == user.id
    end

    test "enforces unique credential_id" do
      user = user_fixture()
      cred_id = :crypto.strong_rand_bytes(32)

      {:ok, _} =
        Accounts.create_user_passkey(user, %{
          credential_id: cred_id,
          public_key: @valid_cose_key
        })

      {:error, changeset} =
        Accounts.create_user_passkey(user, %{
          credential_id: cred_id,
          public_key: @valid_cose_key
        })

      assert "has already been taken" in errors_on(changeset)[:credential_id]
    end
  end

  describe "delete_user_passkey/2" do
    test "deletes a passkey belonging to the user" do
      user = user_fixture()

      {:ok, passkey} =
        Accounts.create_user_passkey(user, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key
        })

      assert {:ok, _} = Accounts.delete_user_passkey(user, passkey.id)
      assert Accounts.list_user_passkeys(user) == []
    end

    test "returns error when passkey doesn't exist" do
      user = user_fixture()
      assert {:error, :not_found} = Accounts.delete_user_passkey(user, Ecto.UUID.generate())
    end

    test "cannot delete another user's passkey" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, passkey} =
        Accounts.create_user_passkey(user1, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key
        })

      assert {:error, :not_found} = Accounts.delete_user_passkey(user2, passkey.id)
    end
  end

  describe "get_user_by_passkey_credential_id/1" do
    test "returns {user, passkey} when credential exists" do
      user = user_fixture()
      cred_id = :crypto.strong_rand_bytes(32)

      {:ok, passkey} =
        Accounts.create_user_passkey(user, %{
          credential_id: cred_id,
          public_key: @valid_cose_key
        })

      assert {found_user, found_passkey} = Accounts.get_user_by_passkey_credential_id(cred_id)
      assert found_user.id == user.id
      assert found_passkey.id == passkey.id
    end

    test "returns nil for unknown credential_id" do
      assert Accounts.get_user_by_passkey_credential_id(:crypto.strong_rand_bytes(32)) == nil
    end

    test "does not return soft-deleted users" do
      user = user_fixture()
      cred_id = :crypto.strong_rand_bytes(32)

      {:ok, _} =
        Accounts.create_user_passkey(user, %{
          credential_id: cred_id,
          public_key: @valid_cose_key
        })

      Accounts.soft_delete_user(user)

      assert Accounts.get_user_by_passkey_credential_id(cred_id) == nil
    end
  end

  describe "update_passkey_after_auth/2" do
    test "updates sign_count and last_used_at" do
      user = user_fixture()

      {:ok, passkey} =
        Accounts.create_user_passkey(user, %{
          credential_id: @valid_credential_id,
          public_key: @valid_cose_key
        })

      assert passkey.sign_count == 0
      assert passkey.last_used_at == nil

      {:ok, updated} = Accounts.update_passkey_after_auth(passkey, 5)
      assert updated.sign_count == 5
      assert updated.last_used_at != nil
    end
  end
end
