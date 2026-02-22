defmodule AniminaWeb.LiveOnlineCountComponentTest do
  use AniminaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Animina.AccountsFixtures

  alias AniminaWeb.LiveOnlineCountComponent

  describe "render/1" do
    test "renders FIDS-style digit boxes with count" do
      html =
        render_component(LiveOnlineCountComponent,
          id: "online-count",
          online_count: 12
        )

      # Each digit gets its own FIDS box
      assert html =~ "fids-digit"
      # Title shows the total count
      assert html =~ ~s(title="12 online")
      # Two separate digit spans
      assert count_occurrences(html, "fids-digit") == 2
      # Shows "online" label
      assert html =~ "online"
    end

    test "renders single digit for low counts" do
      html =
        render_component(LiveOnlineCountComponent,
          id: "online-count",
          online_count: 5
        )

      assert html =~ ~s(title="5 online")
      assert count_occurrences(html, "fids-digit") == 1
    end

    test "renders three digits for triple-digit counts" do
      html =
        render_component(LiveOnlineCountComponent,
          id: "online-count",
          online_count: 142
        )

      assert html =~ ~s(title="142 online")
      assert count_occurrences(html, "fids-digit") == 3
    end

    test "hides display when count is zero" do
      html =
        render_component(LiveOnlineCountComponent,
          id: "online-count",
          online_count: 0
        )

      # Component is hidden when count is 0
      assert html =~ "hidden"
      refute html =~ ~s(title=)
    end
  end

  describe "integration: admin nav bar" do
    test "online count component is mounted for admin user", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin, current_role: "admin")

      {:ok, _view, html} = live(conn, ~p"/status")

      # Component is mounted with fids-digit spans for admin users.
      # Count may vary depending on other presence-tracked test processes.
      assert html =~ "fids-digit"
    end

    test "online count component does NOT render for regular user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/status")

      refute html =~ "fids-digit"
    end
  end

  defp count_occurrences(string, pattern) do
    string
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end
end
