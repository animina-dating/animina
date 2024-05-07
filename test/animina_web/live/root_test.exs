defmodule AniminaWeb.RootTest do
  use AniminaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Animina.Accounts.User

  @valid_attrs %{
    email: "michael@example.com",
    username: "MichaelMunavu",
    name: "Michael",
    hashed_password: Bcrypt.hash_pwd_salt("Michael123"),
    birthday: "1950-01-01",
    height: 180,
    zip_code: "56068",
    gender: "male",
    mobile_phone: "0151-12345678",
    occupation: "Software Engineer",
    language: "en",
    legal_terms_accepted: true
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

    test "Once we add correct user details , we are redirected to the /my/potential-partner/ page",
         %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/")

      {:ok, user} = User.create(@valid_attrs)

      {:ok, _index_live, html} =
        conn |> login_user(user.email, "Michael123") |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end
  end

  defp login_user(conn, email, password) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in/")

    form =
      form(lv, "#basic_user_sign_in_form", user: %{email: email, password: password})

    submit_form(form, conn)
  end
end
