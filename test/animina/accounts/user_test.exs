defmodule Animina.Accounts.UserTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.User

  describe "gravatar_hash calculation" do
    test "calculates the gravatar_hash correctly" do
      assert {:error, _} = User.by_email("bob@example.com")

      Ash.Seed.seed!(%BasicUser{
        email: "bob@example.com",
        username: "bob",
        name: "Bob",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "12345",
        gender: "m",
        mobile_phone: "0151-12345678",
        language: "en",
        legal_terms_accepted: true
      })

      assert {:ok, _} = User.by_email("bob@example.com")
    end
  end
end
