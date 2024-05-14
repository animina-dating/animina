defmodule AniminaWeb.BookmarkComponent do
  @moduledoc """
  This component renders the bookmark card.
  """
  use AniminaWeb, :live_component
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "bookmark:updated:#{assigns.bookmark.id}")
      PubSub.subscribe(Animina.PubSub, "bookmark:deleted:#{assigns.bookmark.id}")
    end

    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      I'm a bookmark
    </div>
    """
  end
end
