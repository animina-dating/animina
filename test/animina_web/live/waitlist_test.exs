defmodule AniminaWeb.WaitlistLiveTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Waitlist Live" do
    setup do
      role =
        if Role.by_name!(:user) == nil do
          Role.create(%{name: :user})
        else
          Role.by_name!(:user)
        end

      admin_role =
        if Role.by_name!(:admin) == nil do
          Role.create!(%{name: :admin})
        else
          Role.by_name!(:admin)
        end

      user_one = create_user_one()
      user_two = create_user_two()

      Credit.create!(%{
        user_id: user_one.id,
        points: 100,
        subject: "Registration bonus"
      })

      # make user one an admin
      UserRole.create(%{
        user_id: user_one.id,
        role_id: admin_role.id
      })

      # make user two a user

      UserRole.create(%{
        user_id: user_two.id,
        role_id: role.id
      })

      user_one = User.by_id!(user_one.id)
      user_two = User.by_id!(user_two.id)

      [
        user_one: user_one,
        user_two: user_two
      ]
    end

    test "Only Admins can visit /admin/waitlist",
         %{
           conn: conn,
           user_one: user_one
         } do
      # User one is an admin hence they can access the waitlist page

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/waitlist")

      assert html =~ "The following users are on the waitlist"
    end

    test "Normal Users cannot visit /admin/waitlist",
         %{
           conn: conn,
           user_two: user_two
         } do
      # User two is a normal user hence they cannot access the waitlist page

      {:error, {:redirect, %{to: url, flash: %{}}}} =
        conn
        |> login_user(%{
          "username_or_email" => user_two.username,
          "password" => "password"
        })
        |> live(~p"/admin/waitlist")

      assert url =~ "/sign-in"
    end

    test "You can see users in the waitlist",
         %{
           conn: conn,
           user_one: user_one
         } do
      # User one is an admin hence they can access the waitlist page

      create_five_users()

      # create user that will be in the waitlist

      {:ok, user} =
        User.create(%{
          email: "waitlist@gmail.com",
          username: "waitlist",
          name: "Waitlist",
          hashed_password: Bcrypt.hash_pwd_salt("password"),
          birthday: "1950-01-01",
          height: 180,
          zip_code: "56068",
          gender: "male",
          mobile_phone: "0151-11345678",
          language: "de",
          country: "Germany",
          legal_terms_accepted: true,
          confirmed_at: DateTime.utc_now()
        })

      user_in_waitlist = User.by_id!(user.id)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/waitlist")

      assert html =~ "The following users are on the waitlist"

      assert html =~ user_in_waitlist.name
    end

    test "You can remove users from the waitlist",
         %{
           conn: conn,
           user_one: user_one
         } do
      # User one is an admin hence they can access the waitlist page

      create_five_users()

      # create user that will be in the waitlist

      {:ok, user} =
        User.create(%{
          email: "waitlist@gmail.com",
          username: "waitlist",
          name: "Waitlist",
          hashed_password: Bcrypt.hash_pwd_salt("password"),
          birthday: "1950-01-01",
          height: 180,
          zip_code: "56068",
          gender: "male",
          mobile_phone: "0151-11345678",
          language: "de",
          country: "Germany",
          legal_terms_accepted: true,
          confirmed_at: DateTime.utc_now()
        })

      user_in_waitlist = User.by_id!(user.id)

      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user_one.username,
          "password" => "password"
        })
        |> live(~p"/admin/waitlist")

      assert html =~ "The following users are on the waitlist"

      assert html =~ user_in_waitlist.name

      index_live
      |> element("#user-in-waitlist-#{user_in_waitlist.id}")
      |> render_click()

      user_removed_from_waitlist = User.by_id!(user_in_waitlist.id)

      assert user_removed_from_waitlist.is_in_waitlist == false
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
        mobile_phone: "0151-12345678",
        language: "de",
        country: "Germany",
        legal_terms_accepted: true
      })

    create_about_me_story(user.id, get_about_me_headline().id)
    create_profile_picture(user.id)

    user
  end

  defp create_user_two do
    {:ok, user} =
      User.create(%{
        email: "mike@example.com",
        username: "mike",
        name: "Mike",
        hashed_password: Bcrypt.hash_pwd_salt("password"),
        birthday: "1950-01-01",
        height: 180,
        zip_code: "56068",
        gender: "male",
        mobile_phone: "0151-12341678",
        language: "de",
        country: "Germany",
        legal_terms_accepted: true
      })

    create_about_me_story(user.id, get_about_me_headline().id)
    create_profile_picture(user.id)

    user
  end

  defp create_five_users do
    for user <- user_details() do
      user =
        user
        |> Map.put(:hashed_password, Bcrypt.hash_pwd_salt("MichaelTheEngineer"))
        |> Map.put(:birthday, "1950-01-01")
        |> Map.put(:height, 180)
        |> Map.put(:zip_code, "56068")
        |> Map.put(:occupation, "Software Engineer")
        |> Map.put(:language, "en")
        |> Map.put(:legal_terms_accepted, true)
        |> Map.put(:country, "Germany")
        |> Map.put(:gender, "male")

      User.create(user)
    end
  end

  defp user_details do
    [
      %{
        email: "test@example.com",
        username: "Maya",
        name: "Maya",
        mobile_phone: "0151-12445678"
      },
      %{
        email: "jones@example.com",
        username: "Jones",
        name: "Jones",
        mobile_phone: "0151-12345671"
      },
      %{
        email: "kim@example.com",
        username: "Kim",
        name: "Kim",
        mobile_phone: "0151-12345672"
      },
      %{
        email: "jama@example.com",
        username: "Jama",
        name: "Jama",
        mobile_phone: "0151-12345673"
      },
      %{
        email: "stefan@example.com",
        username: "Stefan",
        name: "Stefan",
        mobile_phone: "0151-12345674"
      }
    ]
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
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
end
