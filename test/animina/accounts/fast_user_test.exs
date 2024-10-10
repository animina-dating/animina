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
      role = create_admin_role()
      user_role = create_user_role(role, user)
      profile_photo = create_profile_picture(user)

      [
        user: user,
        user_role: user_role,
        profile_photo: profile_photo
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
