defmodule AniminaWeb.ChatTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Bookmark
  alias Animina.Accounts.Credit
  alias Animina.Accounts.Role
  alias Animina.Accounts.User
  alias Animina.Accounts.UserRole
  alias Animina.Accounts.VisitLogEntry
  alias Animina.Narratives.Headline
  alias Animina.Narratives.Story

  describe "Tests the Chat Live" do
    setup do
      public_user = create_public_user()

      private_user = create_private_user()

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
        private_user: private_user
      ]
    end

    test "You see a user's Mini Profile if you visit their chat live", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      # we visit the message box for public user and private user

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{public_user.username}/messages/#{private_user.username}")

      assert html =~ private_user.name
      assert html =~ "#{private_user.height}"
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

  defp login_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: attributes)

    submit_form(form, conn)
  end
end
