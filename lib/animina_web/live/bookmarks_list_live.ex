defmodule AniminaWeb.BookmarksListLive do
  @moduledoc """
  User Bookmarks Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.PubSub

  require Ash.Query

  @impl true
  def mount(
        _,
        %{"language" => language, "reason" => reason, "current_user_id" => current_user_id} =
          _session,
        socket
      ) do
    current_user = Accounts.BasicUser.by_id!(current_user_id)

    socket =
      socket
      |> assign(bookmarks: AsyncResult.loading())
      |> assign(language: language)
      |> assign(current_user: current_user)
      |> assign(reason: reason)
      |> assign(active_tab: :bookmarks)
      |> start_async(:fetch_bookmarks, fn -> fetch_bookmarks(current_user, reason) end)

    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "bookmark:created:#{current_user.id}")
    end

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_async(:fetch_bookmarks, {:ok, data}, socket) do
    %{bookmarks: bookmarks} =
      socket.assigns

    {:noreply,
     socket
     |> assign(
       :bookmarks,
       AsyncResult.ok(bookmarks, data)
     )
     |> stream(:bookmarks, data)}
  end

  @impl true
  def handle_async(:fetch_bookmarks, {:exit, reason}, socket) do
    %{bookmarks: bookmarks} = socket.assigns

    {:noreply, assign(socket, :bookmarks, AsyncResult.failed(bookmarks, {:exit, reason}))}
  end

  @impl true
  def handle_event("destroy_bookmark", %{"id" => id, "dom_id" => dom_id}, socket) do
    {:ok, bookmark} = Accounts.Bookmark.by_id(id)

    case Accounts.Bookmark.unlike(bookmark, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> delete_bookmark_by_dom_id(dom_id)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("An error occurred while deleting the bookmark"))}
    end
  end

  @impl true
  def handle_info(
        %{event: "create", payload: %{data: %Accounts.Bookmark{} = bookmark}},
        socket
      ) do
    {:noreply, insert_new_bookmark(socket, bookmark)}
  end

  @impl true
  def handle_info(
        %{event: "update", payload: %{data: %Accounts.Bookmark{} = bookmark}},
        socket
      ) do
    {:noreply, update_bookmark(socket, bookmark)}
  end

  @impl true
  def handle_info(
        %{event: "destroy", payload: %{data: %Accounts.Bookmark{} = bookmark}},
        socket
      ) do
    {:noreply, delete_bookmark_by_dom_id(socket, "bookmark_" <> bookmark.id)}
  end

  defp insert_new_bookmark(socket, bookmark) do
    socket
    |> stream_insert(:bookmarks, bookmark, at: 0)
  end

  defp update_bookmark(socket, bookmark) do
    socket
    |> stream_insert(:bookmarks, bookmark, at: -1)
  end

  defp delete_bookmark_by_dom_id(socket, dom_id) do
    socket
    |> stream_delete_by_dom_id(:bookmarks, dom_id)
  end

  defp fetch_bookmarks(current_user, reason) do
    Accounts.Bookmark
    |> Ash.Query.for_read(:by_reason, %{owner_id: current_user.id, reason: reason})
    |> Accounts.read!(actor: current_user, page: [limit: 50])
    |> then(& &1.results)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.async_result :let={_bookmarks} assign={@bookmarks}>
        <:loading>
          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <div><.bookmark_card_loading /></div>
            <div><.bookmark_card_loading /></div>
            <div><.bookmark_card_loading /></div>
            <div><.bookmark_card_loading /></div>
            <div><.bookmark_card_loading /></div>
            <div><.bookmark_card_loading /></div>
          </div>
        </:loading>
        <:failed :let={_failure}><%= gettext("There was an error loading bookmarks") %></:failed>

        <div
          class="grid gap-4 md:grid-cols-2 lg:grid-cols-3"
          id={"stream_bookmarks_#{@reason}"}
          phx-update="stream"
        >
          <div class="last:block hidden">
            <p class="text-lg dark:text-white"><%= gettext("No bookmarks found") %></p>
          </div>
          <div :for={{dom_id, bookmark} <- @streams.bookmarks} class="pb-2" id={"#{dom_id}"}>
            <.live_component
              module={AniminaWeb.BookmarkComponent}
              id={"bookmark_#{bookmark.id}"}
              bookmark={bookmark}
              dom_id={dom_id}
              reason={@reason}
            />
          </div>
        </div>
      </.async_result>
    </div>
    """
  end
end
