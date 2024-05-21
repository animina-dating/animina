defmodule AniminaWeb.BookmarksLive do
  @moduledoc """
  User Bookmarks Liveview
  """

  use AniminaWeb, :live_view

  def mount(%{"filter_type" => filter_type}, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :bookmarks)
      |> assign(bookmarks_tab: filter_type)

    {:ok, socket}
  end

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

      <div class="mt-4 space-x-2 space-y-2">

        <.link
          navigate={~p"/my/bookmarks/liked"}
          id="liked_tab"
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "liked", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
        >
          <%= gettext("Liked") %>
        </.link>

        <.link
          navigate={~p"/my/bookmarks/visited"}
          id="visited_tab"
          class={"cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
        >
          <%= gettext("Visited") %>
        </.link>

        <.link
          navigate={~p"/my/bookmarks/most_often_visited"}
          id="most_often_visited_tab"
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "most_often_visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
        >
          <%= gettext("Most Often Visited") %>
        </.link>

        <.link
          navigate={~p"/my/bookmarks/longest_overall_visited"}
          id="longest_overall_visited_tab"
          class={

            "cursor-pointer inline-flex items-center px-4 py-1 font-medium rounded-md " <> if(@bookmarks_tab == "longest_overall_visited", do: "text-blue-100 bg-blue-700", else: "text-blue-700 bg-blue-100")}
        >
          <%= gettext("Longest Overall Visited") %>
        </.link>
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
