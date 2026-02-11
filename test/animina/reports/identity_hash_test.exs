defmodule Animina.Reports.IdentityHashTest do
  use Animina.DataCase, async: true

  alias Animina.Reports.IdentityHash

  describe "hash_phone/1" do
    test "returns consistent hash for the same phone number" do
      hash1 = IdentityHash.hash_phone("+4917012345678")
      hash2 = IdentityHash.hash_phone("+4917012345678")
      assert hash1 == hash2
    end

    test "returns a 64-char lowercase hex string" do
      hash = IdentityHash.hash_phone("+4917012345678")
      assert String.length(hash) == 64
      assert hash == String.downcase(hash)
    end

    test "different phones produce different hashes" do
      hash1 = IdentityHash.hash_phone("+4917012345678")
      hash2 = IdentityHash.hash_phone("+4917087654321")
      assert hash1 != hash2
    end
  end

  describe "hash_email/1" do
    test "returns consistent hash for the same email" do
      hash1 = IdentityHash.hash_email("test@example.com")
      hash2 = IdentityHash.hash_email("test@example.com")
      assert hash1 == hash2
    end

    test "downcases email before hashing" do
      hash1 = IdentityHash.hash_email("Test@Example.COM")
      hash2 = IdentityHash.hash_email("test@example.com")
      assert hash1 == hash2
    end

    test "returns a 64-char lowercase hex string" do
      hash = IdentityHash.hash_email("test@example.com")
      assert String.length(hash) == 64
      assert hash == String.downcase(hash)
    end
  end

  describe "hash_pair/1" do
    test "returns {phone_hash, email_hash} tuple" do
      user = %{mobile_phone: "+4917012345678", email: "test@example.com"}
      {phone_hash, email_hash} = IdentityHash.hash_pair(user)

      assert phone_hash == IdentityHash.hash_phone("+4917012345678")
      assert email_hash == IdentityHash.hash_email("test@example.com")
    end
  end
end
