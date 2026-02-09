defmodule AniminaWeb.LiveUnreadBadgeComponent do
  @moduledoc """
  Live component that displays a real-time unread message badge and chat slot status.

  Shows the chat icon with unread badge, plus slot status (X/Y · ⊕ Z) on desktop.
  Updates on each page navigation (no PubSub).
  """

  use AniminaWeb, :live_component

  alias Animina.Messaging

  @impl true
  def mount(socket) do
    {:ok, assign(socket, unread_count: 0, slot_status: nil, daily_remaining: 0)}
  end

  @impl true
  def update(%{user_id: user_id} = assigns, socket) do
    unread_count = Messaging.unread_count(user_id)
    slot_status = Messaging.chat_slot_status(user_id)
    daily_remaining = max(slot_status.daily_max - slot_status.daily_started, 0)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:unread_count, unread_count)
     |> assign(:slot_status, slot_status)
     |> assign(:daily_remaining, daily_remaining)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="inline-flex items-center gap-1.5">
      <.link
        navigate={~p"/my/messages"}
        class="relative p-2 hover:bg-base-300 rounded-lg transition-colors inline-flex"
      >
        <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 text-base-content/70" />
        <%= if @unread_count > 0 do %>
          <span class="absolute -top-0.5 -end-0.5 min-w-[1.25rem] h-5 flex items-center justify-center text-xs font-bold bg-primary text-primary-content rounded-full px-1">
            {format_count(@unread_count)}
          </span>
        <% end %>
      </.link>
      <span
        :if={@slot_status}
        class="inline-flex items-center gap-1 text-sm text-base-content/50"
      >
        <span>{@slot_status.active}/{@slot_status.max}</span>
        <span class="text-base-content/30">&middot;</span>
        <span title={gettext("New chats available today")}>⊕{@daily_remaining}</span>
      </span>
    </div>
    """
  end

  defp format_count(count) when count > 99, do: "99+"
  defp format_count(count), do: to_string(count)
end
