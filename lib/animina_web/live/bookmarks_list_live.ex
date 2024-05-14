defmodule AniminaWeb.BookmarksListLive do
  @moduledoc """
  User Bookmarks Liveview
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Phoenix.LiveView.AsyncResult

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

  defp fetch_bookmarks(current_user, reason) do
    Accounts.Bookmark
    |> Ash.Query.for_read(:by_reason, %{owner_id: current_user.id, reason: reason})
    |> Accounts.read!(actor: current_user, page: [limit: 50])
    |> then(& &1.results)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Bookmarks list</div>
    """
  end
end
