defmodule Animina.Accounts.UserRoleTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole

  describe "Tests for User Role Resource" do
    test "A user with the admin role can add a user to the admin role group" do
      if Role.by_name!(:user) == nil do
        Role.create(%{name: :user})
      end

      admin_role =
        if Role.by_name!(:admin) == nil do
          Role.create(%{name: :admin})
        else
          Role.by_name!(:admin)
        end

      assert {:ok, first_user} = create_first_user()
      assert {:ok, second_user} = create_second_user()

      assert {:error, _} =
               UserRole.create(
                 %{
                   user_id: second_user.id,
                   role_id: admin_role.id
                 },
                 actor: first_user
               )

      UserRole.create(%{
        user_id: first_user.id,
        role_id: admin_role.id
      })

      assert {:ok, _} =
               UserRole.create(
                 %{
                   user_id: second_user.id,
                   role_id: admin_role.id
                 },
                 actor: first_user
               )
    end
  end

  defp create_first_user do
    User.create(%{
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
      country: "Germany",
      legal_terms_accepted: true
    })
  end

  defp create_second_user do
    User.create(%{
      email: "josh@example.com",
      username: "josh",
      name: "Josh",
      hashed_password: "zzzzzzzzzzz",
      birthday: "1950-01-01",
      height: 180,
      zip_code: "56068",
      country: "Germany",
      gender: "male",
      mobile_phone: "0151-12145678",
      language: "de",
      legal_terms_accepted: true
    })
  end
end
