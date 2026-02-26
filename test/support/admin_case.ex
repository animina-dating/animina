defmodule AniminaWeb.AdminCase do
  @moduledoc """
  Shared test case for admin LiveView tests.

  Provides common imports and admin fixture setup.

  ## Usage

      use AniminaWeb.AdminCase

      describe "My Admin Page" do
        setup :setup_admin

        test "requires admin access", %{conn: conn} do
          assert_requires_admin(conn, ~p"/admin/my-page")
        end

        test "renders page", %{conn: conn, admin: admin} do
          conn = log_in_user(conn, admin, current_role: "admin")
          {:ok, _lv, html} = live(conn, ~p"/admin/my-page")
          assert html =~ "My Page"
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use AniminaWeb.ConnCase, async: true

      import Phoenix.LiveViewTest
      import Animina.AccountsFixtures
      import AniminaWeb.AdminCase
    end
  end

  @doc """
  Setup callback that creates an admin fixture.

  Use with `setup :setup_admin` in your describe block.
  """
  def setup_admin(_context) do
    admin = Animina.AccountsFixtures.admin_fixture()
    %{admin: admin}
  end

  @doc """
  Asserts that the given LiveView path requires admin access.

  Creates a regular user, logs them in, and verifies they get redirected.
  """
  defmacro assert_requires_admin(conn, path) do
    quote do
      user = Animina.AccountsFixtures.user_fixture()
      conn = AniminaWeb.ConnCase.log_in_user(unquote(conn), user)

      assert {:error, {:redirect, %{to: "/"}}} = Phoenix.LiveViewTest.live(conn, unquote(path))
    end
  end
end
