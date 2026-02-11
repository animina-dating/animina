defmodule AniminaWeb.Admin.SpotlightFunnelLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  describe "Spotlight Funnel page" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "requires admin access", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/spotlight/funnel")
    end

    test "renders page with search input", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, _view, html} = live(conn, ~p"/admin/spotlight/funnel")

      assert html =~ "Spotlight Funnel"
      assert html =~ "Search users"
    end

    test "search displays results", %{conn: conn, admin: admin} do
      target = user_fixture(%{display_name: "FunnelTarget"})

      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/spotlight/funnel")

      html =
        view
        |> element("form[phx-change=search]")
        |> render_change(%{"query" => "FunnelTarget"})

      assert html =~ "FunnelTarget"
      assert html =~ target.email
    end

    test "selecting a user loads the funnel", %{conn: conn, admin: admin} do
      target =
        user_fixture(%{
          display_name: "FunnelUser",
          gender: "female",
          preferred_partner_gender: ["male"],
          search_radius: 100
        })

      target
      |> Ecto.Changeset.change(state: "normal")
      |> Animina.Repo.update!()

      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/spotlight/funnel")

      # Search first
      view
      |> element("form[phx-change=search]")
      |> render_change(%{"query" => "FunnelUser"})

      # Select user — triggers async funnel load
      view
      |> element("button[phx-click='select_user'][phx-value-id='#{target.id}']")
      |> render_click()

      # Wait for async handle_info to complete
      html = render(view)

      assert html =~ "All active users"
      assert html =~ "Hard-red conflicts"
    end

    test "direct URL with user_id loads funnel", %{conn: conn, admin: admin} do
      target =
        user_fixture(%{
          display_name: "DirectFunnel",
          gender: "male",
          preferred_partner_gender: ["female"],
          search_radius: 100
        })

      target
      |> Ecto.Changeset.change(state: "normal")
      |> Animina.Repo.update!()

      conn = log_in_user(conn, admin, current_role: "admin")
      {:ok, view, _html} = live(conn, ~p"/admin/spotlight/funnel/#{target.id}")

      # Wait for async handle_info to complete
      html = render(view)

      assert html =~ "DirectFunnel"
      assert html =~ "All active users"
    end
  end
end
