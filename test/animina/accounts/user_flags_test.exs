defmodule Animina.Accounts.UserFlagsTest do
  use Animina.DataCase, async: true
  require Ash.Query
  alias Animina.Traits

  alias Animina.Accounts.User

  alias Animina.Traits.Category
  alias Animina.Traits.Flag
  alias Animina.Traits.FlagTranslation
  alias Animina.Traits.UserFlags

  describe "Tests for the User Flags module" do
    setup do
      category = create_category()
      flag = create_flag(category)
      user = create_user()
      user_two = create_user_two()

      [
        user: user,
        user_two: user_two,
        flag: flag
      ]
    end

    test "The first story you can create is the 'About me' story",
         %{
           user: user,
           flag: flag
         } do
      assert {:ok, _user_flag} = create_user_flag(user, flag, :green)
      assert {:error, _} = create_user_flag(user, flag, :red)
    end

    test "Intersecting flags",
         %{
           user: user,
           user_two: user_two,
           flag: flag
         } do
      # create user one green flags
      {:ok, _user_flag} = create_user_flag(user, flag, :green)

      # create user two white flags
      {:ok, _user_flag} = create_user_flag(user_two, flag, :white)

      # user one has green flags intersecting with user two's white flags
      assert {:ok, [_flag | _]} = intersecting_flags(user.id, user_two.id, "green", "white")

      # user one has no white flags intersecting with user two's white flags
      assert {:ok, []} = intersecting_flags(user.id, user_two.id, "white", "white")
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

  defp create_user_two do
    {:ok, user} =
      User.create(%{
        email: "alice@example.com",
        username: "alice",
        name: "Alice",
        hashed_password: "zzzzzzzzzzz",
        birthday: "1970-08-01",
        height: 170,
        zip_code: "56068",
        gender: "female",
        mobile_phone: "0151-32145678",
        language: "de",
        country: "Germany",
        legal_terms_accepted: true
      })

    user
  end

  defp create_category do
    {:ok, category} =
      Category.create(%{
        name: "Category"
      })

    category
  end

  defp create_flag(category) do
    {:ok, flag} =
      Flag.create(%{
        name: "Flag",
        emoji: "🚩",
        category_id: category.id
      })

    {:ok, _} =
      FlagTranslation.create(%{
        name: "Flag",
        language: "en",
        hashtag: "#flag",
        flag_id: flag.id
      })

    flag
  end

  defp create_user_flag(user, flag, color) do
    UserFlags.create(%{
      user_id: user.id,
      flag_id: flag.id,
      position: 1,
      color: color
    })
  end

  defp intersecting_flags(current_user_id, user_id, current_user_color, user_color) do
    Traits.UserFlags
    |> Ash.ActionInput.for_action(:intersecting_flags_by_color, %{
      current_user: current_user_id,
      current_user_color: current_user_color,
      user: user_id,
      user_color: user_color
    })
    |> Ash.run_action()
  end

  def opposite_color_flags_selected(user_id, color, flag_id) do
    Traits.UserFlags
    |> Ash.Query.for_read(:by_user_id, %{id: user_id, color: color})
    |> Ash.read!()
    |> Enum.map(& &1.flag_id)
    |> Enum.filter(&(&1 != flag_id))
  end
end
