defmodule AniminaWeb.RootTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Photo
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

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
    mobile_phone: "0151-12345678",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true,
    confirmed_at: DateTime.utc_now(),
    country: "Germany"
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

      assert html =~ "We just send you an email"

      assert html =~
               "with a confirmation link. Please click it to confirm your email address. The email is already on its way to you. Please check your spam folder in case it doesn't show up in your inbox"
    end

    test "When more users than the one required per hour sign up , they are added to the waitlist",
         %{conn: conn} do
      #  we first create 5 users , this is the maximum number of users that can sign up in an hour
      # for test env ,
      # for production and development it is 200
      create_five_users()

      {:ok, _index_live, _html} =
        conn
        |> sign_in_user(@valid_attrs)
        |> live(~p"/my/email-validation")

      confirm_user(@valid_attrs)

      # we check that we are redirected back to the too-successful page

      {:error, {:redirect, %{to: url, flash: _}}} =
        conn
        |> login_user(%{
          "username_or_email" => @valid_attrs.username,
          "password" => @valid_attrs.password
        })
        |> live(~p"/my/dashboard")

      assert url == "/my/too-successful"

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => @valid_attrs.username,
          "password" => @valid_attrs.password
        })
        |> live(url)

      assert html =~
               "#{@valid_attrs.name}"

      assert html =~
               "we currently have too many new registrations to handle. That is a good problem for us to have but for you it means that you just landed on a waiting list. We&#39;ll send you an email once our systems are ready. In case this is a spike we are talking minutes or hours."

      user = User.by_username!("MichaelMunavu")
      assert user.is_in_waitlist == true
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

      create_user_about_me_story(
        user,
        get_about_me_headline(),
        "I am a software engineer"
      )

      create_profile_picture(user.id)

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

      create_user_about_me_story(
        user,
        get_about_me_headline(),
        "I am a software engineer"
      )

      create_profile_picture(user.id)

      {:ok, _index_live, html} =
        conn
        |> login_user(%{"username_or_email" => user.email, "password" => @valid_attrs.password})
        |> live(~p"/my/too-successful")

      assert html =~
               "#{user.name}"

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

  defp confirm_user(attributes) do
    user = User.by_username!(attributes.username)

    User.update(user, %{confirmed_at: DateTime.utc_now()})
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
end
