defmodule Animina.Accounts.RegistrationTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story
  alias Animina.Traits
  alias Animina.Traits.Category
  alias Animina.Traits.Flag
  alias Animina.Traits.UserFlags

  describe "Tests for the registration process for a new user" do
    setup do
      category = create_category()
      flags = create_flags(category)
      user = create_user()
      about_me_headline = get_about_me_headline()

      [
        user: user,
        flags: flags,
        category: category,
        about_me_headline: about_me_headline
      ]
    end

    test "Registration", %{user: user, flags: flags, about_me_headline: about_me_headline} do
      # potential partner
      assert {:ok, user} = update_user_potential_partner(user)

      # profile photo
      assert {:ok, photo} = create_user_profile_photo(user)

      # white flags
      assert {:ok, _white_flags} = create_user_flags(user, flags, :white)

      # green flags
      assert {:ok, green_flags} = create_user_flags(user, flags, :green)

      # red flags
      assert {:ok, _red_flags} =
               create_user_flags(
                 user,
                 Enum.reject(flags, fn flag -> Enum.filter(green_flags, &(&1.id == flag.id)) end),
                 :red
               )

      # about me story
      assert {:ok, _story_photo} = create_user_about_me_story(user, photo, about_me_headline)
    end
  end

  defp create_user do
    {:ok, user} =
      User.create(%{
        email: "adam@example.com",
        username: "adam",
        name: "Adam Newuser",
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

  defp update_user_potential_partner(user) do
    user
    |> Ash.Changeset.for_update(:update, %{
      minimum_partner_height: nil,
      maximum_partner_height: 190,
      minimum_partner_age: 18,
      maximum_partner_age: 26,
      search_range: 10,
      partner_gender: "female"
    })
    |> Accounts.update()
  end

  defp create_user_profile_photo(user) do
    Photo.create(%{
      user_id: user.id,
      filename: "e67e65c8-6fdb-4c2d-af36-ea1b461f9219.png",
      original_filename: "photo1.png",
      ext: "png",
      mime: "image/png",
      size: 27_181
    })
  end

  defp create_user_flags(user, flags, color) do
    result =
      Enum.take_random(flags, 3)
      |> Enum.with_index(fn element, index -> {index, element} end)
      |> Enum.map(fn {index, flag} ->
        %{
          flag_id: flag.id,
          user_id: user.id,
          color: color,
          position: index + 1
        }
      end)
      |> Traits.bulk_create(UserFlags, :create, return_records?: true, stop_on_error?: true)

    {:ok, result.records}
  end

  defp create_user_about_me_story(user, photo, headline) do
    {:ok, story} =
      Story.create(%{
        user_id: user.id,
        headline_id: headline.id,
        content: "This is a story about me",
        position: 1
      })

    Photo.create(%{
      user_id: photo.user_id,
      filename: photo.filename,
      original_filename: photo.original_filename,
      mime: photo.mime,
      size: photo.size,
      ext: photo.ext,
      dimensions: photo.dimensions,
      state: photo.state,
      story_id: story.id
    })
  end

  defp create_category do
    {:ok, category} = Category.create(%{name: "Drinks"})

    category
  end

  defp create_flags(category) do
    result =
      [
        %{name: "Gin", emoji: "🥃", category_id: category.id},
        %{name: "Whiskey", emoji: "🥃", category_id: category.id},
        %{name: "Rum", emoji: "🍺", category_id: category.id},
        %{name: "Red Wine", emoji: "🍷", category_id: category.id},
        %{name: "White Wine", emoji: "🥂", category_id: category.id},
        %{name: "Vodka", emoji: "🍹", category_id: category.id},
        %{name: "Brandy", emoji: "🍾", category_id: category.id},
        %{name: "Beer", emoji: "🍻", category_id: category.id}
      ]
      |> Traits.bulk_create(Flag, :create, return_records?: true, stop_on_error?: true)

    result.records
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
