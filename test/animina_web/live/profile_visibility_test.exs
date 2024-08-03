defmodule AniminaWeb.ProfileVisibilityTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.User

  describe "Tests the Profile Visibility Live" do
    setup do
      user = create_user()

      [
        user: user
      ]
    end

    test "When we Visit /my/profile/visibility we can change a page to change profile visibility",
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
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      # we check to ensure we can see the 4 states a user can change to
      assert html =~ "Normal"
      assert html =~ "Hibernate"
      assert html =~ "Archived"
      assert html =~ "Incognito"
    end

    test "The state of the current user will have a corresponding active text next to it",
         %{
           conn: conn,
           user: user
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      assert user.state == :normal

      assert has_element?(index_live, "#active-mark-#{user.state}")
    end

    test "You can click on the Incognito div to change the profile visibility to incognito",
         %{
           conn: conn,
           user: user
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      index_live
      |> element("#user-state-incognito")
      |> render_click()

      user = User.by_id!(user.id)

      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert has_element?(index_live, "#active-mark-incognito")
      refute has_element?(index_live, "#active-mark-normal")

      assert user.state == :incognito
      refute user.state == :normal
    end

    test "You can click on the Hibernate div to change the profile visibility to hibernate",
         %{
           conn: conn,
           user: user
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      index_live
      |> element("#user-state-hibernate")
      |> render_click()

      user = User.by_id!(user.id)

      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert has_element?(index_live, "#active-mark-hibernate")
      refute has_element?(index_live, "#active-mark-normal")

      assert user.state == :hibernate
      refute user.state == :normal
    end

    test "You can click on the Archive to change the profile visibility to archived, you will be auto logged out",
         %{
           conn: conn,
           user: user
         } do
      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      index_live
      |> element("#user-state-archived")
      |> render_click()

      user = User.by_id!(user.id)

      {:error, {:redirect, %{to: _, flash: %{"error" => error}}}} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert error == "You need to be authenticated  confirmed , and have an active account to access this page . If you are already signed up , check your email for the confirmation link"
    end

    test "If a user is incognito , they can go back to the normal state by clicking the Normal Div",
         %{
           conn: conn,
           user: user
         } do
      {:ok, user} = User.incognito(user)

      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      assert user.state == :incognito

      index_live
      |> element("#user-state-normal")
      |> render_click()

      user = User.by_id!(user.id)

      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert has_element?(index_live, "#active-mark-normal")
      refute has_element?(index_live, "#active-mark-incognito")

      assert user.state == :normal
      refute user.state == :incognito
    end

    test "If a user is hibernate , they can go back to the normal state by clicking the Normal Div",
         %{
           conn: conn,
           user: user
         } do
      {:ok, user} = User.hibernate(user)

      {:ok, index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert html =~ "Change Profile Visibility"

      assert user.state == :hibernate

      index_live
      |> element("#user-state-normal")
      |> render_click()

      user = User.by_id!(user.id)

      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/my/profile/visibility")

      assert has_element?(index_live, "#active-mark-normal")
      refute has_element?(index_live, "#active-mark-hibernate")

      assert user.state == :normal
      refute user.state == :hibernate
    end
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
        gender: "male",
        mobile_phone: "0151-12345678",
        language: "en",
        legal_terms_accepted: true,
        confirmed_at: DateTime.utc_now()
      })

    user
  end

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end
end
