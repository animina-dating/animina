defmodule Animina.Accounts.UserTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

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
    legal_terms_accepted: true,
    country: "Germany"
  }

  describe "User Resource Tests" do
    test "create a new user" do
      assert {:error, _} = User.by_email("bob@example.com")

      assert {:ok, _} =
               User.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 name: "Bob",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 country: "Germany",
                 gender: "male",
                 mobile_phone: "0151-12345678",
                 language: "de",
                 legal_terms_accepted: true
               })

      assert {:ok, _} = User.by_email("bob@example.com")
    end

    test "You cannot create a user with a country that is not in the list of allowed countries" do
      assert {:error, _} = User.by_email("bob@example.com")

      assert {:ok, _} =
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
                 legal_terms_accepted: true,
                 country: "Germany"
               })

      assert {:ok, _} = User.by_email("bob@example.com")

      assert {:error, _} =
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
                 legal_terms_accepted: true,
                 country: "My Fake Country"
               })
    end

    test "updated a  user" do
      assert {:error, _} = User.by_email("bob@example.com")

      assert {:ok, user} =
               User.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 name: "Bob",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 occupation: "Engineer",
                 gender: "male",
                 mobile_phone: "0151-12345678",
                 language: "de",
                 country: "Germany",
                 legal_terms_accepted: true
               })

      assert user.occupation =~ "Engineer"

      {:ok, updated_user} =
        User.update(user, %{
          occupation: "New Occupation"
        })

      assert updated_user.occupation =~ "New Occupation"

      assert {:ok, _} = User.by_email("bob@example.com")
    end

    test "User.destroy deletes a user" do
      assert {:error, _} = User.by_email("bob@example.com")

      assert {:ok, user} =
               User.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 name: "Bob",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 occupation: "Engineer",
                 gender: "male",
                 country: "Germany",
                 mobile_phone: "0151-12345678",
                 language: "de",
                 legal_terms_accepted: true
               })

      assert user.occupation =~ "Engineer"

      User.destroy(user)

      assert {:error, _} = User.by_email("bob@example.com")
    end

    test "does not create a user if they have a bad username" do
      assert {:error, _} =
               User.create(%{
                 email: "name@example.com",
                 username: "my",
                 name: "Bobby",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 gender: "male",
                 country: "Germany",
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
                 country: "Germany",
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
               User.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 name: "Bob",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 country: "Germany",
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
               User.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 country: "Germany",
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
               User.create(%{
                 email: "bob@example.com",
                 username: "bob",
                 name: "Bob",
                 hashed_password: "zzzzzzzzzzz",
                 birthday: "1950-01-01",
                 height: 180,
                 zip_code: "56068",
                 country: "Germany",
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
               User.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.incognito(user)

      assert user.state == :incognito
    end

    test "unban/1 returns a user with the state :normal who was :banned" do
      assert {:ok, user} =
               User.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.ban(user)

      assert user.state == :banned

      {:ok, user} = User.unban(user)

      assert user.state == :normal
    end

    test "recover/1 returns a user with the state :normal from :archived " do
      assert {:ok, user} =
               User.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.archive(user)

      assert user.state == :archived

      {:ok, user} = User.recover(user)

      assert user.state == :normal
    end

    test "destroy/1  deletes a user from the database" do
      assert {:ok, user} =
               User.create(@create_user_params)

      assert user.state == :normal
      User.destroy(user)

      assert {:error, _} = User.by_id(user.id)
    end

    test "reactivate/1 returns a user with the state :normal from :incognito or :hibernate " do
      assert {:ok, user} =
               User.create(@create_user_params)

      create_user_about_me_story(
        user,
        get_about_me_headline(),
        "I am a software engineer"
      )

      create_profile_picture(user.id)

      user = User.by_id!(user.id)

      assert user.state == :normal

      {:ok, user} = User.hibernate(user)

      assert user.state == :hibernate

      {:ok, user} = User.reactivate(user)

      assert user.state == :normal
    end

    test "reactivate/1 will fail if the user does not have an about me story with an image or a profile photo" do
      assert {:ok, user} =
               User.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.hibernate(user)

      assert user.state == :hibernate

      # Reactivating a user without an about me story with an image or a profile photo should fail

      {:error, _} = User.reactivate(user)
    end

    test "normalize/1 returns a user with the state :normal from any state" do
      assert {:ok, user} =
               User.create(@create_user_params)

      assert user.state == :normal

      {:ok, user} = User.hibernate(user)

      assert user.state == :hibernate

      {:ok, user} = User.normalize(user)

      assert user.state == :normal
    end

    test "you cannot update the registration_completed_at field to a time  more than 1  minute in the past or the future" do
      assert {:ok, user} =
               User.create(@create_user_params)

      two_minutes_ago = DateTime.add(DateTime.utc_now(), -2, :minute)
      two_minutes_later = DateTime.add(DateTime.utc_now(), 2, :minute)

      assert {:error, _} = User.update(user, %{registration_completed_at: two_minutes_ago})
      assert {:error, _} = User.update(user, %{registration_completed_at: two_minutes_later})

      assert {:ok, _} = User.update(user, %{registration_completed_at: DateTime.utc_now()})
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
    {:ok, user} =
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
        legal_terms_accepted: true,
        country: "Germany"
      })

    create_user_about_me_story(
      user,
      get_about_me_headline(),
      "I am a software engineer"
    )

    create_profile_picture(user.id)

    {:ok, user}
  end

  defp create_user_about_me_story(user, headline, story_content) do
    {:ok, story} =
      Story.create(%{
        user_id: user.id,
        headline_id: headline.id,
        content: story_content,
        position: 1
      })

    file_path = Temp.path!(basedir: "priv/static/uploads", suffix: ".jpg")

    file_path_without_uploads = String.replace(file_path, "uploads/", "")

    Photo.create(%{
      user_id: user.id,
      story_id: story.id,
      filename: file_path_without_uploads,
      original_filename: file_path_without_uploads,
      size: 100,
      ext: "jpg",
      mime: "image/jpeg"
    })

    story
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

  defp get_about_me_headline do
    case Headline.by_subject("About me") do
      {:ok, headline} ->
        headline

      _ ->
        {:ok, headline} =
          Headline.create(%{
            subject: "About me",
            position: 90
          })

        headline
    end
  end

  defp create_profile_picture(user_id) do
    file_path = Temp.path!(basedir: "priv/static/uploads", suffix: ".jpg")

    file_path_without_uploads = String.replace(file_path, "uploads/", "")

    Photo.create(%{
      user_id: user_id,
      filename: file_path_without_uploads,
      original_filename: file_path_without_uploads,
      size: 100,
      ext: "jpg",
      mime: "image/jpeg"
    })
  end
end
