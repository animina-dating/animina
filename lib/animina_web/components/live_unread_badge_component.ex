defmodule AniminaWeb.LiveUnreadBadgeComponent do
  @moduledoc """
  Live component that displays a real-time unread message badge.

  This component fetches the unread count on each update. For real-time updates,
  the parent LiveView should subscribe to the user's message topic and send
  updates to this component.
  """

  use AniminaWeb, :live_component

  alias Animina.Messaging

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :unread_count, 0)}
  end

  @impl true
  def update(%{user_id: user_id} = assigns, socket) do
    unread_count = Messaging.unread_count(user_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="inline-block">
      <.link
        navigate={~p"/messages"}
        class="relative p-2 hover:bg-base-300 rounded-lg transition-colors inline-flex"
      >
        <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 text-base-content/70" />
        <%= if @unread_count > 0 do %>
          <span class="absolute -top-0.5 -end-0.5 min-w-[1.25rem] h-5 flex items-center justify-center text-xs font-bold bg-primary text-primary-content rounded-full px-1">
            {format_count(@unread_count)}
          </span>
        <% end %>
      </.link>
    </div>
    """
  end

  defp format_count(count) when count > 99, do: "99+"
  defp format_count(count), do: to_string(count)
end
