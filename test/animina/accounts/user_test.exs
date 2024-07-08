defmodule Animina.Accounts.UserTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole

  @create_user_params %{
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
  }

  describe "User Resource Tests" do
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

    test "when you create a user , a user role is created with the role 'user'" do
      if Role.by_name!(:user) == nil do
        Role.create(%{name: :user})
      end

      assert {:ok, user} =
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
                 legal_terms_accepted: true
               })

      assert {:ok, user_roles} = UserRole.by_user_id(user.id)

      assert Enum.any?(user_roles, fn user_role -> user_role.role.name == :user end)
    end

    test "hibernate/1 returns a user with the state :hibernate" do
      assert {:ok, user} =
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

      assert user.state == :normal

      {:ok, user} = User.hibernate(user)

      assert user.state == :hibernate
    end

    test "ban/1 returns a user with the state :banned" do
      assert {:ok, user} =
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

      assert user.state == :normal

      {:ok, user} = User.ban(user)

      assert user.state == :banned
    end

    test "investigate/1 returns a user with the state :under_investigation" do
      assert {:ok, user} =
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

      assert user.state == :normal

      {:ok, user} = User.investigate(user)

      assert user.state == :under_investigation
    end

    test "incognito/1 returns a user with the state :incognito" do
      assert {:ok, user} =
               BasicUser.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.incognito(user)

      assert user.state == :incognito
    end

    test "unban/1 returns a user with the state :normal who was :banned" do
      assert {:ok, user} =
               BasicUser.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.ban(user)

      assert user.state == :banned

      {:ok, user} = User.unban(user)

      assert user.state == :normal
    end

    test "recover/1 returns a user with the state :normal from :archived " do
      assert {:ok, user} =
               BasicUser.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.archive(user)

      assert user.state == :archived

      {:ok, user} = User.recover(user)

      assert user.state == :normal
    end

    test "reactivate/1 returns a user with the state :normal from :incognito or :hibernate " do
      assert {:ok, user} =
               BasicUser.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.hibernate(user)

      assert user.state == :hibernate

      {:ok, user} = User.reactivate(user)

      assert user.state == :normal
    end

    test "normalize/1 returns a user with the state :normal from any state" do
      assert {:ok, user} =
               BasicUser.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.hibernate(user)

      assert user.state == :hibernate

      {:ok, user} = User.normalize(user)

      assert user.state == :normal
    end

    test "make_admin/1 takes  a user id and makes that user an admin" do
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

      assert {:ok, user_role} = User.make_admin(%{user_id: first_user.id})

      assert user_role.role_id == admin_role.id
      assert(user_role.user_id == first_user.id)
    end

    test "remove_admin/1 takes  a user id and removes all their admin roles" do
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

      assert {:ok, user_role} = User.make_admin(%{user_id: first_user.id})

      assert user_role.role_id == admin_role.id
      assert user_role.user_id == first_user.id

      user = User.by_id!(first_user.id)

      assert user_admin?(user) == true

      assert {:ok, :admin_roles_removed} = User.remove_admin(%{user_id: first_user.id})

      user = User.by_id!(first_user.id)

      assert user_admin?(user) == false
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
      legal_terms_accepted: true
    })
  end

  def user_admin?(user) do
    case user.roles do
      [] ->
        false

      roles ->
        roles
        |> Enum.map(fn x -> x.name end)
        |> Enum.any?(fn x -> x == :admin end)
    end
  end
end
