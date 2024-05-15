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
      |> assign(bookmarks_tab: "liked")

    {:ok, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, bookmarks_tab: tab)}
  end

  def render(assigns) do
    ~H"""
    <div class="px-4">
      <h1 class="text-2xl font-semibold dark:text-white">
        <%= gettext("Bookmarks") %>
      </h1>

      <div class="mt-4 space-x-2">
        <a
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "liked", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
          phx-click={JS.push("switch_tab", value: %{tab: "liked"})}
        >
          <%= gettext("Liked") %>
        </a>

        <a
          class={"cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
          phx-click={JS.push("switch_tab", value: %{tab: "visited"})}
        >
          <%= gettext("Visited") %>
        </a>
      </div>

      <div
        id="bookmarks_tab_liked"
        class={"py-8 " <> if(@bookmarks_tab == "liked", do: "", else: "hidden h-0")}
      >
        <%= live_render(
          @socket,
          AniminaWeb.BookmarksListLive,
          session: %{
            "reason" => :liked,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "bookmarks_list:liked",
          sticky: true
        ) %>
      </div>

      <div
        id="bookmarks_tab_visited"
        class={"py-8 " <> if(@bookmarks_tab == "visited", do: "", else: "hidden h-0")}
      >
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
