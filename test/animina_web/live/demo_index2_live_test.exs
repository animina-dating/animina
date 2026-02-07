defmodule AniminaWeb.DemoIndex2LiveTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AccountsFixtures
  import Phoenix.LiveViewTest

  describe "Index page" do
    test "renders the self-hosted server card instead of mission statement link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # The new self-hosted server card should be present
      assert html =~ "Self-hosted in Germany"
      assert html =~ "own physical hardware in Germany"

      # The old mission statement link should be gone
      refute html =~ "/demo/mission_statement"
      refute html =~ "Our Mission Statement"
    end

    test "mission statement page no longer exists", %{conn: conn} do
      assert_raise FunctionClauseError, fn ->
        live(conn, "/demo/mission_statement")
      end
    end

    test "redirects waitlisted user to /users/waitlist", %{conn: conn} do
      user = user_fixture(%{language: "en", display_name: "Waitlisted User"})
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/users/waitlist"}}} = live(conn, ~p"/")
    end

    test "does not redirect non-waitlisted user", %{conn: conn} do
      user = user_fixture(%{language: "en", display_name: "Active User"})

      user =
        user
        |> Ecto.Changeset.change(state: "normal")
        |> Animina.Repo.update!()

      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Self-hosted in Germany"
    end
  end
end
