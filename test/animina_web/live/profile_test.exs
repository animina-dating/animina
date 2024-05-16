defmodule AniminaWeb.ProfileTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.User
  alias Animina.Accounts.Bookmark
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Profile Live" do
    setup do
      public_user = create_public_user()

      private_user = create_private_user()
      about_me_headline = get_about_me_headline()

      public_user_story =
        create_user_about_me_story(public_user, about_me_headline, "This is a public user story")

      private_user_story =
        create_user_about_me_story(
          private_user,
          about_me_headline,
          "This is a private user story"
        )

      [
        public_user: public_user,
        private_user: private_user,
        public_user_story: public_user_story,
        private_user_story: private_user_story
      ]
    end

    test "Anonymous Users Cannot view a Private Users Page", %{
      conn: conn,
      private_user: private_user,
      private_user_story: private_user_story
    } do
      {:ok, _view, html} = live(conn, "/#{private_user.username}")

      assert html =~
               "This profile either doesn&#39;t exist or you don&#39;t have enough points to access it. You need 20 points to access a profile page."

      refute html =~ private_user_story.content
      refute html =~ Ash.CiString.value(private_user.username)
    end

    test "Anonymous Users Cannot view a Public Users Page", %{
      conn: conn,
      public_user: public_user,
      public_user_story: public_user_story
    } do
      {:ok, _view, html} = live(conn, "/#{public_user.username}")

      conn = get(conn, "/#{public_user.username}")
      assert response(conn, 200)
      assert html =~ public_user.name
      assert html =~ public_user.name
      assert html =~ public_user_story.content
    end

    test "Once  a logged in user views a profile , a bookmark is created  ", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      # we check that there is no bookmark for the user and the profile

      assert {:error, _} =
               Bookmark.by_owner_user_and_reason(public_user.id, private_user.id, :visited)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

      public_user = User.by_username!(public_user.username)
      private_user = User.by_username!(private_user.username)

      assert html =~ private_user.name

      assert {:ok, bookmark} =
               Bookmark.by_owner_user_and_reason(public_user.id, private_user.id, :visited)

      assert bookmark.owner_id == public_user.id
      assert bookmark.user_id == private_user.id
      assert bookmark.reason == :visited
    end

    
  end

  defp create_public_user do
    {:ok, user} =
      User.create(%{
        email: "adam@example.com",
        username: "adam",
        name: "Adam Newuser",
        hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "en",
        legal_terms_accepted: true
      })

    user
  end

  defp create_private_user do
    {:ok, user} =
      User.create(%{
        email: "private@example.com",
        username: "private",
        name: "Private",
        hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-22345678",
        language: "en",
        is_private: true,
        legal_terms_accepted: true
      })

    user
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

  defp create_user_about_me_story(user, headline, story_content) do
    {:ok, story} =
      Story.create(%{
        user_id: user.id,
        headline_id: headline.id,
        content: story_content,
        position: 1
      })

    story
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end
end
