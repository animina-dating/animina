defmodule AniminaWeb.BookmarksLive do
  @moduledoc """
  User Bookmarks Liveview
  """

  use AniminaWeb, :live_view

  def mount(_, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :bookmarks)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Bookmarks page</h1>

      <div>
        <%= live_render(
          @socket,
          AniminaWeb.BookmarksListLive,
          session: %{
            "reason" => :visited,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "bookmarks_list:visited",
          sticky: true
        ) %>
      </div>
    </div>
    """
  end
end
