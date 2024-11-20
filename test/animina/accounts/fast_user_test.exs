defmodule Animina.Accounts.FastUserTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.FastUser
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole

  describe "Tests for the FastUser resource" do
    setup do
      user = create_user()
      male_user = create_male_user()
      female_user = create_female_user()
      role = create_admin_role()
      user_role = create_user_role(role, user)
      profile_photo = create_profile_picture(user)

      [
        user: user,
        user_role: user_role,
        profile_photo: profile_photo,
        male_user: male_user,
        female_user: female_user
      ]
    end

    test "Can read user by username",
         %{
           user: user,
           profile_photo: profile_photo
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(:by_id_email_or_username, %{username: user.username})
        |> Ash.run_action()

      assert {:ok, user_result} = result
      assert profile_photo.id == user_result.profile_photo.id
    end

    test "Can read user by id",
         %{
           user: user
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(:by_id_email_or_username, %{id: user.id})
        |> Ash.run_action()

      assert {:ok, user_result} = result
      assert user.zip_code == user_result.city.zip_code
      assert 0 == user_result.credit_points
    end

    test "Can read user by email",
         %{
           user: user,
           user_role: user_role
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(:by_id_email_or_username, %{email: user.email})
        |> Ash.run_action()

      assert {:ok, user_result} = result
      assert [] != Enum.filter(user_result.roles, fn role -> role.id == user_role.id end)
    end

    test "Can read a list of users",
         %{
           user: user
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(:list, %{})
        |> Ash.run_action()

      assert {:ok, users} = result
      assert users.count > 0
      assert [] != Enum.filter(users.results, fn u -> u.id == user.id end)
    end

    test "Can read a public list of male users registered in the last 60 days",
         %{
           male_user: user
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(
          :public_users_who_created_an_account_in_the_last_number_of_days,
          %{
            gender: "male"
          }
        )
        |> Ash.run_action()

      assert {:ok, users} = result
      assert users.count > 0

      assert [] != Enum.filter(users.results, fn u -> u.id == user.id end)
    end

    test "Can read a public list of female users registered in the last 60 days",
         %{
           female_user: user
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(
          :public_users_who_created_an_account_in_the_last_number_of_days,
          %{
            gender: "female"
          }
        )
        |> Ash.run_action()

      assert {:ok, users} = result
      assert users.count > 0

      assert [] != Enum.filter(users.results, fn u -> u.id == user.id end)
    end

    test "An error is returned for a user that does not exist",
         %{
           user: _user
         } do
      result =
        FastUser
        |> Ash.ActionInput.for_action(:by_id_email_or_username, %{email: "a@example.com"})
        |> Ash.run_action()

      assert {:error, _} = result
    end
  end

  defp create_user do
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
        country: "Germany",
        legal_terms_accepted: true
      })

    user
  end

  defp create_male_user do
    {:ok, user} =
      User.create(%{
        email: "john@example.com",
        username: "john",
        name: "John",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345679",
        language: "de",
        country: "Germany",
        legal_terms_accepted: true,
        confirmed_at: DateTime.utc_now(),
        registration_completed_at: DateTime.utc_now()
      })

    user
  end

  defp create_female_user do
    {:ok, user} =
      User.create(%{
        email: "alice@example.com",
        username: "alice",
        name: "Alice",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1970-01-01",
        height: 180,
        zip_code: "56068",
        gender: "female",
        mobile_phone: "0151-12345689",
        language: "de",
        country: "Germany",
        legal_terms_accepted: true,
        confirmed_at: DateTime.utc_now(),
        registration_completed_at: DateTime.utc_now()
      })

    user
  end

  defp create_admin_role do
    {:ok, role} =
      Role.create(%{name: :admin})

    role
  end

  defp create_user_role(role, user) do
    {:ok, role} =
      UserRole.create(%{
        user_id: user.id,
        role_id: role.id
      })

    role
  end

  defp create_profile_picture(user) do
    file_path = Temp.path!(basedir: "priv/static/uploads", suffix: ".jpg")

    file_path_without_uploads = String.replace(file_path, "uploads/", "")

    {:ok, photo} =
      Photo.create(%{
        user_id: user.id,
        filename: file_path_without_uploads,
        original_filename: file_path_without_uploads,
        size: 100,
        ext: "jpg",
        mime: "image/jpeg"
      })

    photo
  end
end
