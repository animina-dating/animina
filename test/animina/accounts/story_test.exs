defmodule Animina.Accounts.StoryTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.BasicUser
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests for the Story Resource" do
    setup do
      [
        user: create_user(),
        get_about_me_headline: get_about_me_headline(),
        get_non_about_me_headline: get_non_about_me_headline()
      ]
    end

    test "The first story you can create is the 'About me' story",
         %{
           user: user,
           get_about_me_headline: get_about_me_headline,
           get_non_about_me_headline: get_non_about_me_headline
         } do
      # when we try to add the first story with a headline that is not 'About me', we should get an error
      assert {:error, _} = create_non_about_me_story(user.id, get_non_about_me_headline.id)

      # when we try to add the first story with the 'About me' headline, we should be able to do so
      assert {:ok, _about_me_story} = create_about_me_story(user.id, get_about_me_headline.id)
      # now we can add another story with a different headline
      assert {:ok, _} = create_non_about_me_story(user.id, get_non_about_me_headline.id)
    end

    test "You cannot delete a story with the 'About me' headline if it is the last one remaining ",
         %{
           user: user,
           get_about_me_headline: get_about_me_headline,
           get_non_about_me_headline: get_non_about_me_headline
         } do
      # insert about me story as the first story
      {:ok, about_me_story} = create_about_me_story(user.id, get_about_me_headline.id)

      # when you try to delete the story with the 'About me' headline, you should get an error
      assert {:error, _} = Story.destroy(about_me_story)

      # insert another story
      create_non_about_me_story(user.id, get_non_about_me_headline.id)

      # now when there is another story with a different headline, you should
      # be able to delete the story with the 'About me' headline
      assert :ok = Story.destroy(about_me_story)
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
        legal_terms_accepted: true
      })

    user
  end

  defp get_about_me_headline do
    {:ok, about_me_headline} =
      Headline.by_subject("About me")

    about_me_headline
  end

  defp get_non_about_me_headline do
    {:ok, headlines} = Headline.read()

    headlines
    |> Enum.filter(&(&1.subject != "About me"))
    |> Enum.random()
  end

  defp create_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 1
    })
  end

  defp create_non_about_me_story(user_id, headline_id) do
    Story.create(%{
      user_id: user_id,
      headline_id: headline_id,
      content: "This is a story about me",
      position: 2
    })
  end
end
