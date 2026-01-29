defmodule AniminaWeb.DebugLiveTest do
  use AniminaWeb.ConnCase, async: true

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
      assert html =~ "Animina"

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

      # BEAM Info section
      assert html =~ "BEAM Info"
      assert html =~ "Process Count"
      assert html =~ "Schedulers"

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
  end
end
