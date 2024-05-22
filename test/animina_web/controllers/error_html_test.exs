defmodule AniminaWeb.ErrorHTMLTest do
  use AniminaWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    rendered_content = render(AniminaWeb.ErrorHTML, "404", "html", [])

    html =
      rendered_content.static
      |> Enum.join("")

    assert String.contains?(
             html,
             "This profile either doesn't exist or you don't have enough points to access it."
           )
  end

  test "renders 500.html" do
    assert render_to_string(AniminaWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
