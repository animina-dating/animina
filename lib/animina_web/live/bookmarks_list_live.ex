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
      |> start_async(:fetch_bookmarks, fn -> fetch_bookmarks(current_user) end)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_async(:fetch_bookmarks, {:ok, data}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_bookmarks, {:exit, reason}, socket) do
    %{bookmarks: bookmarks} = socket.assigns

    {:noreply, assign(socket, :bookmarks, AsyncResult.failed(bookmarks, {:exit, reason}))}
  end

  defp fetch_bookmarks(current_user) do
    Accounts.Bookmark
    |> Ash.Query.for_read(:read, %{owner_id: current_user.id})
    |> Accounts.read(actor: current_user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Bookmarks list</div>
    """
  end
end
