defmodule Animina.Accounts.UserTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.User

  describe "create BasicUser" do
    test "create a new user" do
      assert {:error, _} = User.by_email("bob@example.com")

      assert {:ok, _} =
               BasicUser.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 name: "Bob",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 gender: "male",
                 mobile_phone: "0151-12345678",
                 language: "de",
                 legal_terms_accepted: true
               })

      assert {:ok, _} = User.by_email("bob@example.com")
    end

    test "does not create a user if they have a bad username" do
      assert {:error, _} =
               BasicUser.create(%{
                 email: "name@example.com",
                 username: "my",
                 name: "Bobby",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 gender: "male",
                 mobile_phone: "0151-12315678",
                 language: "de",
                 legal_terms_accepted: true
               })
    end
  end
end
