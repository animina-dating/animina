defmodule AniminaWeb.HealthControllerTest do
  use AniminaWeb.ConnCase, async: true

  test "GET /health returns 200 with status ok", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
