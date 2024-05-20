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
          id="liked_tab"
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "liked", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
          phx-click={JS.push("switch_tab", value: %{tab: "liked"})}
        >
          <%= gettext("Liked") %>
        </a>

        <a
          id="visited_tab"
          class={"cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
          phx-click={JS.push("switch_tab", value: %{tab: "visited"})}
        >
          <%= gettext("Visited") %>
        </a>

        <a
          id="most_often_visited_tab"
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "most_often_visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
          phx-click={JS.push("switch_tab", value: %{tab: "most_often_visited"})}
        >
          <%= gettext("Most Often Visited") %>
        </a>

        <a
          id="longest_overall_visited_tab"
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "longest_overall_visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
          phx-click={JS.push("switch_tab", value: %{tab: "longest_overall_visited"})}
        >
          <%= gettext("Longest Overall Visited") %>
        </a>
      </div>

      <div :if={@bookmarks_tab == "liked"} id="bookmarks_tab_liked" class="py-8 ">
        <%= live_render(
          @socket,
          AniminaWeb.BookmarksListLive,
          session: %{
            "reason" => :liked,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "bookmarks_list_liked",
          sticky: true
        ) %>
      </div>

      <div :if={@bookmarks_tab == "visited"} id="bookmarks_tab_visited" class="py-8 ">
        <%= live_render(
          @socket,
          AniminaWeb.BookmarksListLive,
          session: %{
            "reason" => :visited,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "bookmarks_list_visited",
          sticky: true
        ) %>
      </div>

      <div
        :if={@bookmarks_tab == "most_often_visited"}
        id="bookmarks_tab_most_often_visited"
        class="py-8 "
      >
        <%= live_render(
          @socket,
          AniminaWeb.BookmarksListLive,
          session: %{
            "reason" => :most_often_visited,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "bookmarks_list_most_often_visited",
          sticky: true
        ) %>
      </div>

      <div
        :if={@bookmarks_tab == "longest_overall_visited"}
        id="bookmarks_tab_longest_overall_visited"
        class="py-8 "
      >
        <%= live_render(
          @socket,
          AniminaWeb.BookmarksListLive,
          session: %{
            "reason" => :longest_overall_visited,
            "current_user_id" => @current_user.id,
            "language" => @language
          },
          id: "bookmarks_list_longest_overall_visited",
          sticky: true
        ) %>
      </div>
    </div>
    """
  end
end
