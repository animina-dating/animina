defmodule AniminaWeb.UpdateProfileTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Photo
  alias Animina.Accounts.User
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Update Profile Live" do
    setup do
      user_one = create_user_one()

      Credit.create!(%{
        user_id: user_one.id,
        points: 100,
        subject: "Registration bonus"
      })

      [
        user_one: user_one
      ]
    end

    test "You can visit the update profile page and you will see your details",
         %{
           conn: conn,
           user_one: user_one
         } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/my/profile/edit")

      assert html =~ "Update Your Profile"

      assert html =~ "#{user_one.username}"
      assert html =~ "#{user_one.name}"
    end

    test "You can update your details by editing the form",
         %{
           conn: conn,
           user_one: user_one
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/my/profile/edit")

      assert html =~ "Update Your Profile"

      assert html =~ "#{user_one.username}"
      assert html =~ "#{user_one.occupation}"

      {:ok, _index_live, html} =
        index_live
        |> form("#basic_user_update_form", user: %{"occupation" => "New Occupation"})
        |> render_submit()
        |> follow_redirect(
          conn
          |> login_user(%{
            "username_or_email" => user_one.username,
            "password" => "password"
          }),
          "/#{user_one.username}"
        )

      refute html =~ "#{user_one.occupation}"
      assert html =~ "New Occupation"
    end
  end

  defp create_user_one do
    {:ok, user} =
      User.create(%{
        email: "bob@example.com",
        username: "bob",
        name: "Bob",
        hashed_password: Bcrypt.hash_pwd_salt("password"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        occupation: "Engineer",
        mobile_phone: "0151-12345678",
        language: "de",
        country: "Germany",
        legal_terms_accepted: true,
        confirmed_at: DateTime.utc_now()
      })

    create_user_about_me_story(user, get_about_me_headline(), "This is my story")
    create_profile_picture(user.id)
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
