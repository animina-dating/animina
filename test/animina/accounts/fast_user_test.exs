defmodule Animina.Accounts.FastUserTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.Role
  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.UserRole
  alias Animina.Accounts.Photo

  describe "Tests for the Fast User module" do
    setup do
      user = create_user()
      role = create_admin_role()
      create_user_role(role, user)
      create_profile_picture(user)

      [
        user: user
      ]
    end

    test "The first story you can create is the 'About me' story",
         %{
           user: user
         } do
      assert {:ok, _} = {:ok, []}
    end
  end

  defp create_user do
    {:ok, user} =
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
