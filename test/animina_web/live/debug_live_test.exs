defmodule AniminaWeb.DebugLiveTest do
  use AniminaWeb.ConnCase, async: true

  import Animina.AccountsFixtures
  import Phoenix.LiveViewTest

  describe "GET /debug" do
    test "renders the debug page with all sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/debug")

      # Page title
      assert html =~ "System Debug"

      # Versions section
      assert html =~ "Versions"
      assert html =~ "Elixir"
      assert html =~ "Erlang/OTP"
      assert html =~ "ANIMINA"

      # Database section
      assert html =~ "Database"

      # BEAM Memory section
      assert html =~ "BEAM Memory"
      assert html =~ "Total"
      assert html =~ "Processes"
      assert html =~ "ETS"
      assert html =~ "Atoms"
      assert html =~ "Binaries"

      # System Load section
      assert html =~ "System Load"

      # BEAM / CPU Info section
      assert html =~ "BEAM / CPU Info"
      assert html =~ "Process Count"
      assert html =~ "Schedulers"
      assert html =~ "CPU Model"
      assert html =~ "CPU Cores"

      # Deployment section
      assert html =~ "Deployment"
      assert html =~ "Deployed At"
      assert html =~ "Uptime"
    end

    test "handles periodic refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/debug")

      # Simulate the refresh timer message
      send(view.pid, :refresh)

      # Page should still render correctly after refresh
      html = render(view)
      assert html =~ "System Debug"
      assert html =~ "Versions"
      assert html =~ "Database"
    end

    test "renders shared layout with ANIMINA nav", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/debug")

      assert html =~ "ANIMINA"
    end

    test "does not show online users graph for unauthenticated visitors", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/debug")

      refute html =~ "Online Users"
      refute html =~ "24 hours"
    end

    test "does not show online users graph for regular users", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/debug")

      refute html =~ "Online Users"
      refute html =~ "24 hours"
    end

    test "shows online users graph for admin users", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, _view, html} = live(conn, ~p"/debug")

      assert html =~ "Online Users"
      assert html =~ "24 hours"
      assert html =~ "48 hours"
      assert html =~ "7 days"
      assert html =~ "28 days"
    end

    test "admin can switch time frames", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, view, _html} = live(conn, ~p"/debug")

      html =
        view
        |> element("[phx-click='set_time_frame'][phx-value-frame='7d']")
        |> render_click()

      assert html =~ "Online Users"
    end

    test "shows empty state message when no data exists", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, _view, html} = live(conn, ~p"/debug")

      assert html =~ "No data yet"
    end

    # Registration graph tests

    test "does not show registration graph for unauthenticated visitors", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/debug")

      refute html =~ "New Registrations"
      refute html =~ "Registered"
      refute html =~ "Confirmed"
    end

    test "does not show registration graph for regular users", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/debug")

      refute html =~ "New Registrations"
      refute html =~ "Registered"
      refute html =~ "Confirmed"
    end

    test "shows registration graph for admin users", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, _view, html} = live(conn, ~p"/debug")

      assert html =~ "New Registrations"
      assert html =~ "Registered"
      assert html =~ "Confirmed"
      assert html =~ "7 days"
      assert html =~ "28 days"
    end

    test "admin can switch registration time frame", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, view, _html} = live(conn, ~p"/debug")

      html =
        view
        |> element("[phx-click='set_reg_time_frame'][phx-value-frame='28d']")
        |> render_click()

      assert html =~ "New Registrations"
    end
  end
end
