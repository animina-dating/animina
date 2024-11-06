defmodule Animina.Accounts.PhotoTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.OptimizedPhoto
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User

  describe "Tests for Photo Resource" do
    test "A user can create a photo with the required attributes" do
      {:ok, user} = create_first_user()

      assert {:error, _} = Photo.create(%{})

      assert {:ok, _} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })
    end

    test "Once a user creates a photo , optimized versions are created" do
      {:ok, user} = create_first_user()

      assert {:error, _} = Photo.create(%{})

      assert {:ok, photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })

      assert {:ok, optimized_photos} = OptimizedPhoto.by_photo_id(%{photo_id: photo.id})

      assert Enum.count(optimized_photos) == 3
    end

    test "update/2 updates the photo with the new attributes" do
      {:ok, user} = create_first_user()

      assert {:error, _} = Photo.create(%{})

      assert {:ok, photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })

      assert {:ok, updated_photo} =
               Photo.update(photo, %{
                 filename: "new_filename"
               })

      assert updated_photo.filename == "new_filename"
    end

    test "read/0 returns all photos" do
      {:ok, user} = create_first_user()

      assert {:error, _} = Photo.create(%{})

      assert {:ok, photos} = Photo.read()

      assert Enum.empty?(photos) == true

      assert {:ok, _photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })

      assert {:ok, photos} = Photo.read()

      assert Enum.empty?(photos) == false
    end

    test "destroy/1 deletes the photo" do
      {:ok, user} = create_first_user()

      assert {:error, _} = Photo.create(%{})

      assert {:ok, photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })

      assert :ok = Photo.destroy(photo)

      assert {:ok, photos} = Photo.read()

      assert Enum.empty?(photos) == true
    end

    test "by_user_id/1 returns all photos for a user" do
      {:ok, user} = create_first_user()

      assert {:error, _} = Photo.create(%{})

      assert {:ok, _photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })

      assert {:ok, photos} = Photo.by_user_id(user.id)

      assert Enum.empty?(photos) == false
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
end
