defmodule AniminaWeb.NonAboutMeStoryRedirectsTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.User

  @valid_attrs %{
    email: "michael@example.com",
    username: "MichaelMunavu",
    name: "Michael",
    password: "MichaelTheEngineer",
    birthday: "1950-01-01",
    height: 180,
    zip_code: "56068",
    gender: "male",
    mobile_phone: "0151-12345672",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true,
    country: "Germany"
  }

  @valid_create_user_attrs %{
    email: "michael@example.com",
    username: "MichaelMunavu",
    name: "Michael",
    hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
    birthday: "1950-01-01",
    height: 180,
    zip_code: "56068",
    gender: "male",
    mobile_phone: "0151-12345673",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true,
    confirmed_at: DateTime.utc_now(),
    country: "Germany"
  }

  @valid_create_second_user_attrs %{
    email: "james@example.com",
    username: "James",
    name: "James",
    hashed_password: Bcrypt.hash_pwd_salt("MichaelTheEngineer"),
    birthday: "1950-01-01",
    height: 180,
    zip_code: "56068",
    gender: "male",
    mobile_phone: "0151-12345674",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true,
    confirmed_at: DateTime.utc_now(),
    country: "Germany"
  }

  describe "Tests to ensure you cannot access restricted pages without an about me story" do
    test "A user can login with their email and password", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "A user cannot access the dashboard without an about me story", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:error,
       {:redirect,
        %{
          to: url,
          flash: %{"error" => error}
        }}} =
        conn
        |> login_user(%{
          "username_or_email" => user.email,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/dashboard/")

      assert url == "/my/about-me"
      assert error == "You need to have an About me story to access this page"
    end

    test "A user cannot create a new story without an about me story", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:error,
       {:redirect,
        %{
          to: url,
          flash: %{"error" => error}
        }}} =
        conn
        |> login_user(%{
          "username_or_email" => user.email,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/stories/new/")

      assert url == "/my/about-me"
      assert error == "You need to have an About me story to access this page"
    end

    test "A user cannot create a new post without an about me story", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:error,
       {:redirect,
        %{
          to: url,
          flash: %{"error" => error}
        }}} =
        conn
        |> login_user(%{
          "username_or_email" => user.email,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/posts/new/")

      assert url == "/my/about-me"
      assert error == "You need to have an About me story to access this page"
    end

    test "A user cannot visit the bookmarks page without an about me story", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:error,
       {:redirect,
        %{
          to: url,
          flash: %{"error" => error}
        }}} =
        conn
        |> login_user(%{
          "username_or_email" => user.email,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/bookmarks/")

      assert url == "/my/about-me"
      assert error == "You need to have an About me story to access this page"
    end

    test "A user cannot visit the report user page without an about me story", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, second_user} = User.create(@valid_create_second_user_attrs)

      {:error,
       {:redirect,
        %{
          to: url,
          flash: %{"error" => error}
        }}} =
        conn
        |> login_user(%{
          "username_or_email" => user.email,
          "password" => @valid_attrs.password
        })
        |> live(~p"/#{second_user.username}/report")

      assert url == "/my/about-me"
      assert error == "You need to have an About me story to access this page"
    end

    test "A user cannot visit the chat  page of another user without an about me story", %{
      conn: conn
    } do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, second_user} = User.create(@valid_create_second_user_attrs)

      {:error,
       {:redirect,
        %{
          to: url,
          flash: %{"error" => error}
        }}} =
        conn
        |> login_user(%{
          "username_or_email" => user.email,
          "password" => @valid_attrs.password
        })
        |> live(~p"/#{user.username}/messages/#{second_user.username}")

      assert url == "/my/about-me"
      assert error == "You need to have an About me story to access this page"
    end
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end
end
