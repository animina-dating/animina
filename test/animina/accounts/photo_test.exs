defmodule Animina.Accounts.PhotoTest do
  use Animina.DataCase, async: true
  alias Animina.Accounts.OptimizedPhoto
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

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

    test "Once a user deletes their profile photo , their state changes to hibernated" do
      {:ok, user} = create_first_user()

      assert user.state == :normal

      # we ensure the story_id is nil , which means it is a profile photo
      assert {:ok, photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 user_id: user.id,
                 ext: "ext"
               })

      #  we delete the photo

      assert :ok = Photo.destroy(photo)

      assert {:ok, user} = User.by_id(user.id)

      # we now can see the state of the user changes to hibernate

      assert user.state == :hibernate
    end

    test "Once a user deletes their about me photo , their state changes to hibernated" do
      {:ok, user} = create_first_user()

      assert {:ok, about_me_story} = create_about_me_story(user.id, get_about_me_headline().id)

      assert user.state == :normal

      # we create a photo for the about me story
      assert {:ok, photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 story_id: about_me_story.id,
                 user_id: user.id,
                 ext: "ext"
               })

      #  we delete the photo

      assert :ok = Photo.destroy(photo)

      assert {:ok, user} = User.by_id(user.id)

      # we now can see the state of the user changes to hibernate

      assert user.state == :hibernate
    end

    test "A user can delete any other photo apart from the about me photo and the profile photo and
          their state does not change" do
      {:ok, user} = create_first_user()

      assert {:ok, about_me_story} = create_about_me_story(user.id, get_about_me_headline().id)

      assert {:ok, _about_me_photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 story_id: about_me_story.id,
                 user_id: user.id,
                 ext: "ext"
               })

      assert {:ok, non_about_me_story} =
               create_non_about_me_story(user.id, get_non_about_me_headline().id)

      assert {:ok, non_about_me_photo} =
               Photo.create(%{
                 filename: "filename",
                 original_filename: "original_filename",
                 mime: "mime",
                 size: 100,
                 story_id: non_about_me_story.id,
                 user_id: user.id,
                 ext: "ext"
               })

      assert user.state == :normal

      #  we delete the non about me photo

      assert :ok = Photo.destroy(non_about_me_photo)

      assert {:ok, user} = User.by_id(user.id)

      # we now can see the state of the user does not change

      assert user.state == :normal
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

  defp create_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 1
    })
  end

  defp get_non_about_me_headline do
    {:ok, headlines} = Headline.read()

    case headlines do
      [] ->
        {:ok, headline} =
          Headline.create(%{
            subject: "Non About me",
            position: 91
          })

        headline

      _ ->
        headlines
        |> Enum.filter(&(&1.subject != "About me"))
        |> Enum.random()
    end
  end

  defp create_non_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 2
    })
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
end
