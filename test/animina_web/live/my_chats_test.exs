defmodule AniminaWeb.MyChatTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Profile Visibility Live" do
    setup do
      user = create_user()

      [
        user: user
      ]
    end

    test "You cannot visit the all chats page if you are not logged in",
         %{
           conn: conn
         } do
      {:error, {:redirect, %{flash: %{"error" => message}, to: url}}} =
        conn
        |> live(~p"/my/chats")

      assert message == "You need to login or sign up to access this page"
      assert url == "/"
    end

    test "You can access the chats page if you are logged in and with an about me story and profile picture",
         %{
           conn: conn,
           user: user
         } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/chats")

      assert html =~ "My Chats"
    end

    defp create_user do
      {:ok, user} =
        User.create(%{
          email: "adam@example.com",
          username: "adam",
          name: "Adam Newuser",
          hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
          birthday: "1950-01-01",
          height: 180,
          zip_code: "56068",
          country: "Germany",
          gender: "male",
          mobile_phone: "0151-12345678",
          language: "en",
          legal_terms_accepted: true,
          confirmed_at: DateTime.utc_now()
        })

      create_about_me_story(user.id, get_about_me_headline().id)
      create_profile_picture(user.id)

      user
    end

    defp create_about_me_story(user_id, headline_id) do
      Story.create(%{
        user_id: user_id,
        headline_id: headline_id,
        content: "This is a story about me",
        position: 1
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

    defp create_profile_picture(user_id) do
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

    defp login_user(conn, attributes) do
      {:ok, lv, _html} = live(conn, ~p"/sign-in/")

      form =
        form(lv, "#basic_user_sign_in_form", user: attributes)

      submit_form(form, conn)
    end
  end
end
