defmodule AniminaWeb.ShutdownTest do
  use AniminaWeb.ConnCase, async: false

  @farewell_de "ANIMINA stellt den Betrieb ein"
  @farewell_en "ANIMINA is shutting down"

  describe "with shutdown mode enabled" do
    setup do
      Application.put_env(:animina, :shutdown_mode, true)
      on_exit(fn -> Application.delete_env(:animina, :shutdown_mode) end)
      :ok
    end

    test "the root path serves the farewell page in German and English", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      assert response =~ @farewell_de
      assert response =~ @farewell_en
      assert response =~ "https://vutuv.de"
      assert response =~ "https://vutuv.de/wintermeyer"
      assert response =~ "https://github.com/wintermeyer/animina"
      assert response =~ "sw@wintermeyer-consulting.de"
      assert response =~ "28. August 2026"
      assert response =~ "28 August 2026"
      assert response =~ "/images/animina-landing-page.jpg"
    end

    test "the page carries the shutdown date as a letter date" do
      assert build_conn() |> get(~p"/") |> html_response(200) =~ "31. Juli 2026"
    end

    test "the page links from the top to the English section anchor" do
      response = build_conn() |> get(~p"/") |> html_response(200)

      assert response =~ ~s(href="#english")
      assert response =~ ~s(id="english")
    end

    test "all app routes serve the farewell page" do
      for path <- [
            "/discover",
            "/users/log_in",
            "/users/register",
            "/my/messages",
            "/my/settings",
            "/admin/roles",
            "/status"
          ] do
        assert build_conn() |> get(path) |> html_response(200) =~ @farewell_de
      end
    end

    test "POST requests are intercepted as well" do
      assert build_conn() |> post("/users/log_in", %{}) |> html_response(200) =~ @farewell_de
    end

    test "legally required pages remain reachable" do
      for path <- ["/impressum", "/datenschutz", "/agb"] do
        response = build_conn() |> get(path) |> html_response(200)
        refute response =~ @farewell_de
      end
    end

    test "the health check endpoint stays up for the deploy pipeline" do
      assert build_conn() |> get("/health") |> response(200)
    end

    test "the farewell page links to the legal pages" do
      response = build_conn() |> get(~p"/") |> html_response(200)

      assert response =~ "/impressum"
      assert response =~ "/datenschutz"
    end
  end

  describe "with shutdown mode disabled" do
    test "the root path serves the regular landing page", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      refute response =~ @farewell_de
    end
  end
end
