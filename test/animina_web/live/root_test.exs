defmodule AniminaWeb.RootTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole

  @valid_attrs %{
    email: "michael@example.com",
    username: "MichaelMunavu",
    name: "Michael",
    password: "MichaelTheEngineer",
    birthday: "1950-01-01",
    height: 180,
    zip_code: "56068",
    gender: "male",
    mobile_phone: "0151-12345678",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true
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
    mobile_phone: "0151-12345678",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true,
    confirmed_at: DateTime.utc_now()
  }

  describe "Tests the Registration flow" do
    test "The registration form is displayed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "#basic_user_form")
    end

    test "Once we make changes to the registration form , we see any errors if they are there", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> form("#basic_user_form", user: %{"username" => "w"})
        |> render_change()

      assert html =~ "Username length must be greater than or equal to 2"

      html =
        view
        |> form("#basic_user_form", user: %{"password" => "pass"})
        |> render_change()

      assert html =~ "Password length must be greater than or equal to 8"
    end

    test "Once we add correct user details , we are redirected to /my/email-validation where we see information about how to confirm our accounts.",
         %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/")

      {:ok, _index_live, html} =
        conn
        |> sign_in_user(@valid_attrs)
        |> live(~p"/my/email-validation")

      assert html =~ "We just send you an email to #{@valid_attrs.email} with a confirmation link"
    end

    test "Once we add correct user details , we are redirected to /my/email-validation then to  /my/potential-partner/ page after confirmation",
         %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/")

      {:ok, _index_live, _html} =
        conn
        |> sign_in_user(@valid_attrs)
        |> live(~p"/my/email-validation")

      confirm_user(@valid_attrs)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => @valid_attrs.username,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "Once we add correct user details , a user is added and given the 'user' role",
         %{conn: conn} do
      if Role.by_name!(:user) == nil do
        Role.create(%{name: :user})
      end

      {:ok, _view, _html} = live(conn, "/")

      {:ok, _index_live, _html} =
        conn
        |> sign_in_user(@valid_attrs)
        |> live(~p"/my/email-validation")

      confirm_user(@valid_attrs)

      {:ok, _index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => @valid_attrs.username,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/potential-partner/")

      user = User.by_username!(@valid_attrs.username)

      assert {:ok, user_roles} = UserRole.by_user_id(user.id)

      assert Enum.any?(user_roles, fn user_role -> user_role.role.name == :user end)
    end

    test "A user can login with their email and password", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "A user can login with their username and password", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.username, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "A user can login with their username that has an @ at the start and password", %{
      conn: conn
    } do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => "@#{user.username}",
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "Once a user logs in for the first time , if they visit the potential partner page
    , they are given 100 credit points as Registration Bonus and 100 as Daily Bonus",
         %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      current_points = User.by_username!(user.username).credit_points

      {:ok, index_live, _html} =
        conn
        |> login_user(%{"username_or_email" => user.username, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      # if you go to /my/potential-partner after signing up,
      # you get a registration bonus and a daily bonus so now 200 points

      updated_points = current_points + 200

      assert has_element?(index_live, "#current-user-credit-points", "#{updated_points}")
    end

    test "Once a user logs in and they are taken to their page or any other page apart from the
    potential partner page for the first time of the day , they get 100 daily bonus points",
         %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      current_points = User.by_username!(user.username).credit_points

      {:ok, index_live, _html} =
        conn
        |> login_user(%{"username_or_email" => user.username, "password" => @valid_attrs.password})
        |> live(~p"/#{user.username}")

      # if you go to /my/potential-partner after signing up, you
      # get a registration bonus and a daily bonus so now 200 points

      updated_points = current_points + 100

      assert has_element?(index_live, "#current-user-credit-points", "#{updated_points}")
    end

    test "A user cannot login  if an account is under investigation", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.investigate(user)

      {:error,
       {:redirect,
        %{to: "/sign-in?redirect_to=/my/potential-partner/", flash: %{"error" => error}}}} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert error ==
               "You need to be authenticated  confirmed , and have an active account to access this page . If you are already signed up , check your email for the confirmation link"
    end

    test "A user cannot login  if an account is banned", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.ban(user)

      {:error,
       {:redirect,
        %{to: "/sign-in?redirect_to=/my/potential-partner/", flash: %{"error" => error}}}} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert error ==
               "You need to be authenticated  confirmed , and have an active account to access this page . If you are already signed up , check your email for the confirmation link"
    end

    test "A user cannot login  if an account is archived", %{conn: conn} do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.archive(user)

      {:error,
       {:redirect,
        %{to: "/sign-in?redirect_to=/my/potential-partner/", flash: %{"error" => error}}}} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert error ==
               "You need to be authenticated  confirmed , and have an active account to access this page . If you are already signed up , check your email for the confirmation link"
    end

    test "A user can login with their email and password if their account is hibernated", %{
      conn: conn
    } do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.hibernate(user)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "A user can login with their email and password if their account is incognito", %{
      conn: conn
    } do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.incognito(user)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "A user is taken to to the too successful page if they are in the waitlist", %{
      conn: conn
    } do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.update(user, %{is_in_waitlist: true})

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/too-successful")

      assert html =~
               "Hi #{user.name}"

      assert html =~
               "we currently have too many new registrations to handle"
    end

    test "A user in the waitlist cannot access other pages", %{
      conn: conn
    } do
      {:ok, user} = User.create(@valid_create_user_attrs)

      {:ok, user} = User.update(user, %{is_in_waitlist: true})

      {:error, {:redirect, %{to: url, flash: _flash}}} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/dashboard")

      assert url ==
               "/my/too-successful"
    end
  end

  defp sign_in_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/")

    form =
      form(lv, "#basic_user_form", user: attributes)

    submit_form(form, conn)
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end

  defp confirm_user(attributes) do
    user = User.by_username!(attributes.username)

    User.update(user, %{confirmed_at: DateTime.utc_now()})
  end
end
