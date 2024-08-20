defmodule AniminaWeb.DeleteAccountTest do
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

    test "When we Visit /my/profile/delete_account we can delete the account after 10 seconds",
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
        |> live(~p"/my/profile/delete_account")

      assert html =~ "Delete Your Account"

      assert html =~
               "You can delete your account here but you have to wait"
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
