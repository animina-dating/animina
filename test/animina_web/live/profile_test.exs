defmodule AniminaWeb.ProfileTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole
  alias Animina.Accounts.VisitLogEntry
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

      create_profile_picture(public_user.id)
      create_profile_picture(private_user.id)

      Credit.create!(%{
        user_id: private_user.id,
        points: 100,
        subject: "Registration bonus"
      })

      Credit.create!(%{
        user_id: public_user.id,
        points: 100,
        subject: "Registration bonus"
      })

      [
        public_user: public_user,
        private_user: private_user,
        public_user_story: public_user_story,
        private_user_story: private_user_story
      ]
    end

    test "Anonymous Users Get a 404 Error Page when they visit Private Users Page", %{
      conn: conn,
      private_user: private_user
    } do
      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{private_user.username}") |> response(404)
      end
    end

    test "Anonymous Users Can view a Public Users Page", %{
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

    test "Logged in users can view a private user's page", %{
      conn: conn,
      private_user: private_user,
      public_user: public_user
    } do
      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => public_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{private_user.username}"
        )

      assert response(conn, 200)
    end

    test "Logged in users can view a public user's page", %{
      conn: conn,
      private_user: private_user,
      public_user: public_user
    } do
      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => private_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}"
        )

      assert response(conn, 200)
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

    test "Once  a logged in user views a profile , a bookmark is created  and a visit log entry ",
         %{
           conn: conn,
           public_user: public_user,
           private_user: private_user
         } do
      # we check that there is no bookmark for the user and the profile

      assert {:error, _} =
               Bookmark.by_owner_user_and_reason(public_user.id, private_user.id, :visited)

      #  we check that there is no visit log entry for the user and the profile

      assert {:ok, []} = VisitLogEntry.by_user_id(public_user.id)

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

      # we then assert a visit log entry is created for the user and the profile

      assert {:ok, [visit_log_entry]} = VisitLogEntry.by_user_id(public_user.id)

      assert visit_log_entry.user_id == public_user.id
    end

    test "If you are logged in and you visit /my/profile you are redirected to  your profile with your username",
         %{
           conn: conn,
           public_user: public_user
         } do
      {_, {:live_redirect, %{to: username}}} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile")

      assert username == "/#{public_user.username}"
    end

    test "Anonymous Users Get a 404 Error Page when they visit `my/profile`", %{
      conn: conn
    } do
      assert_raise Animina.Fallback, fn ->
        get(conn, "/my/profile") |> response(404)
      end
    end

    test "If an account is under investigation , the profile returns a 404", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.investigate(public_user)

      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "If an account is banned , the profile returns a 404", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.ban(public_user)

      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "If an account is archived , the profile returns a 404", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.archive(public_user)

      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "If an account is hibernate , the profile returns a 404 if you are not the owner", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.hibernate(public_user)

      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "If an account is hibernate , the owner of the profile can view it", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.hibernate(public_user)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{user.username}"
        )

      assert response(conn, 200)
    end

    test "If an account is incognito , the profile returns a 404 if you are not the owner", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.incognito(public_user)

      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "If an account is incognito , the owner of the profile can view it", %{
      conn: conn,
      public_user: public_user
    } do
      {:ok, user} = User.incognito(public_user)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{user.username}"
        )

      assert response(conn, 200)
    end

    test "If an account is under investigation , admins can view that profile", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, _user} = User.investigate(public_user)

      admin_role = create_admin_role()

      create_admin_user_role(private_user.id, admin_role.id)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => private_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}"
        )

      assert response(conn, 200)
    end

    test "If an account is incognito , admins can view that profile", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, _user} = User.incognito(public_user)

      admin_role = create_admin_role()

      create_admin_user_role(private_user.id, admin_role.id)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => private_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}"
        )

      assert response(conn, 200)
    end

    test "If an account is hibernate, admins can view that profile", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, _user} = User.hibernate(public_user)

      admin_role = create_admin_role()

      create_admin_user_role(private_user.id, admin_role.id)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => private_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}"
        )

      assert response(conn, 200)
    end

    test "If an account is banned , admins can view that profile", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, _user} = User.ban(public_user)

      admin_role = create_admin_role()

      create_admin_user_role(private_user.id, admin_role.id)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => private_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}"
        )

      assert response(conn, 200)
    end

    test "If an account is archived , admins can view that profile", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, _user} = User.archive(public_user)

      admin_role = create_admin_role()

      create_admin_user_role(private_user.id, admin_role.id)

      conn =
        get(
          conn
          |> login_user(%{
            "username_or_email" => private_user.username,
            "password" => "MichaelTheEngineer"
          }),
          "/#{public_user.username}"
        )

      assert response(conn, 200)
    end

    test "Users That Are Banned are automatically logged out", %{
      conn: conn,
      private_user: private_user,
      public_user: public_user
    } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

      assert html =~ private_user.name

      {:ok, user} = User.ban(private_user)

      # now you cannot access the private profile which means you are logged out
      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "Users Under Investigation are automatically logged out", %{
      conn: conn,
      private_user: private_user,
      public_user: public_user
    } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

      assert html =~ private_user.name

      {:ok, user} = User.investigate(private_user)

      # now you cannot access the private profile which means you are logged out
      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
    end

    test "Users That Are Archived are automatically logged out", %{
      conn: conn,
      private_user: private_user,
      public_user: public_user
    } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

      assert html =~ private_user.name

      {:ok, user} = User.archive(private_user)

      # now you cannot access the private profile which means you are logged out
      assert_raise Animina.Fallback, fn ->
        get(conn, "/#{user.username}") |> response(404)
      end
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
        country: "Germany",
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
        country: "Germany",
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

  defp create_admin_role do
    {:ok, role} =
      Role.create(%{
        name: :admin
      })

    role
  end

  defp create_admin_user_role(user_id, role_id) do
    {:ok, user_role} =
      UserRole.create(%{
        user_id: user_id,
        role_id: role_id
      })

    user_role
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end
end
