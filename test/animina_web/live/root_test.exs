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

      {:ok, _index_live, html} =
        conn |> sign_in_user(@valid_attrs) |> live(~p"/my/potential-partner/")

      assert html =~ "Criteria for your new partner"
    end

    test "Once we add correct user details , a user is added and given the 'user' role",
         %{conn: conn} do
      if Role.by_name!(:user) == nil do
        Role.create(%{name: :user})
      end

      {:ok, _view, _html} = live(conn, "/")

      {:ok, _index_live, _html} =
        conn |> sign_in_user(@valid_attrs) |> live(~p"/my/potential-partner/")

      user = User.by_username!(@valid_attrs.username)

      assert {:ok, user_roles} = UserRole.by_user_id(user.id)

      assert Enum.any?(user_roles, fn user_role -> user_role.role.name == :user end)
    end
  end

  defp sign_in_user(conn, attributes) do
    {:ok, lv, _html} = live(conn, ~p"/")

    form =
      form(lv, "#basic_user_form", user: attributes)

    submit_form(form, conn)
  end
end
