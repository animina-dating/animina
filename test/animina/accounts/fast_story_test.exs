defmodule Animina.Accounts.FastStoryTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.Narratives.FastStory
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests for the Fast Story Resource" do
    setup do
      user = create_user()

      about_me_headline = get_about_me_headline()
      other_headline = get_other_headline()
      about_me_story = create_about_me_story(user.id, about_me_headline.id)
      other_story = create_other_story(user.id, other_headline.id)
      other_story_photo = create_story_photo(user, other_story.id)

      [
        user: user,
        about_me_headline: about_me_headline,
        other_headline: other_headline,
        about_me_story: about_me_story,
        other_story: other_story,
        other_story_photo: other_story_photo
      ]
    end

    test "Can read stories for a user",
         %{
           user: user,
           about_me_story: about_me_story,
           other_story_photo: other_story_photo
         } do
      {:ok, offset} =
        FastStory
        |> Ash.ActionInput.for_action(:by_user_id, %{id: user.id})
        |> Ash.run_action()

      # result is not empty
      assert true = offset.results != []

      # atleast one of the stories is the about me story
      assert [] != Enum.filter(offset.results, &(&1.id == about_me_story.id))

      # the number of stories for the user is 2
      assert 2 == offset.count

      # atleast one of the stories has a photo with an id equal to the other_story_photo id
      assert [] !=
               Enum.filter(offset.results, &(&1.photo != nil))
               |> Enum.filter(&(&1.photo.id == other_story_photo.id))
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

  defp get_other_headline do
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

  defp create_about_me_story(user_id, headline_id) do
    {:ok, story} =
      Story.create(%{
        user_id: user_id,
        headline_id: headline_id,
        content: "This is a story about me",
        position: 1
      })

    story
  end

  defp create_other_story(user_id, headline_id) do
    {:ok, story} =
      Story.create(%{
        user_id: user_id,
        headline_id: headline_id,
        content: "This is another story which is not an about me story",
        position: 2
      })

    story
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
        country: "Germany",
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "de",
        legal_terms_accepted: true
      })

    user
  end

  defp create_story_photo(user, story_id) do
    file_path = Temp.path!(basedir: "priv/static/uploads", suffix: ".jpg")

    file_path_without_uploads = String.replace(file_path, "uploads/", "")

    {:ok, photo} =
      Photo.create(%{
        story_id: story_id,
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
