defmodule Animina.Accounts.StoryTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.User
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

    test "calculates the gravatar_hash correctly", %{
      user: user,
      get_about_me_headline: get_about_me_headline,
      get_non_about_me_headline: get_non_about_me_headline
    } do
      # IO.inspect(user)
      # IO.inspect(get_about_me_headline)
      # IO.inspect(get_non_about_me_headline)
      # IO.inspect(create_about_me_story(user.id, get_about_me_headline.id))

      assert {:ok, _} = Story.destroy(create_about_me_story(user.id, get_about_me_headline.id))
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
    {:ok, story} =
      Story.create(%{
        user_id: user_id,
        headline_id: headline_id,
        content: "This is a story about me",
        position: 1
      })

    story
  end
end
