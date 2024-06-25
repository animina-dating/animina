defmodule AniminaWeb.ReportTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.Credit

  alias Animina.Accounts.User

  describe "Tests the Report Profile Feature" do
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

    test "Once  a logged in user views a profile ,they can see the button to add a report  ", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")


      private_user = User.by_username!(private_user.username)

      assert html =~ private_user.name
      assert html =~ "Report Account"
    end

    test "Once You click on the Report Account Button , you see a form to report the user", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

      {:error, {:live_redirect, %{kind: :push, to: redirect_url}}} =
        index_live
        |> element("a", "Report Account")
        |> render_click()

      assert redirect_url =~ "/#{private_user.username}/report"

      {:ok, _index_live, html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(redirect_url)

      assert html =~
               "To report an account is a serious act. The account will be deactivated right away and will be investigated by our team. Please tell us why you report the account."
    end


    test "Once You Fill In the form , the user state changes to :under_investigation , a report record is added and you are redirected to '/dashboard'", %{
      conn: conn,
      public_user: public_user,
      private_user: private_user
    } do
      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(~p"/#{private_user.username}")

        assert private_user.state == :normal

      {_, {:live_redirect, %{kind: :push, to: redirect_url}}} =
        index_live
        |> element("a", "Report Account")
        |> render_click()



      {:ok, index_live, _html} =
        conn
        |> login_user(%{
          "username_or_email" => public_user.username,
          "password" => "MichaelTheEngineer"
        })
        |> live(redirect_url)

       {_, {:live_redirect, %{kind: :push, to: redirect_url}}} =
        index_live
        |> form("#report-form", report: %{"description" => "This is a report against a user"})
        |> render_submit()

        assert redirect_url =~ "/my/dashboard"
        user= User.by_username!(private_user.username)
        assert user.state == :under_investigation



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
