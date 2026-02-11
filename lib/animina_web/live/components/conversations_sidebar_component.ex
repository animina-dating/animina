defmodule AniminaWeb.ConversationsSidebarComponent do
  @moduledoc """
  Conversations sidebar component for the spotlight page.

  Renders as a fixed panel on the right (desktop) or a slide-in drawer (mobile).
  Shows all active conversations with avatars, last message preview, and unread badges.
  """

  use AniminaWeb, :live_component

  alias Animina.Photos

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Backdrop (mobile) --%>
      <div
        class="fixed inset-0 bg-black/30 z-40 lg:hidden"
        phx-click="toggle_conversations"
      >
      </div>

      <%!-- Panel --%>
      <div class="fixed top-16 right-0 bottom-0 w-80 lg:w-96 bg-base-100 border-l border-base-300 z-50 flex flex-col shadow-xl">
        <%!-- Header --%>
        <div class="flex items-center justify-between p-4 border-b border-base-300">
          <h2 class="font-semibold text-lg">{gettext("Conversations")}</h2>
          <button phx-click="toggle_conversations" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <%!-- Conversation list --%>
        <div class="flex-1 overflow-y-auto">
          <div :if={@conversations == []} class="text-center py-12 text-base-content/50">
            <.icon name="hero-chat-bubble-left-right" class="h-8 w-8 mx-auto mb-2 opacity-40" />
            <p class="text-sm">{gettext("No conversations yet")}</p>
          </div>

          <.link
            :for={conv <- @conversations}
            navigate={~p"/my/messages?conversation=#{conv.conversation.id}"}
            class={[
              "flex items-center gap-3 px-4 py-3 hover:bg-base-200/50 transition-colors border-b border-base-200/50",
              if(conv.unread, do: "bg-primary/5")
            ]}
          >
            <%!-- Avatar --%>
            <div class="flex-shrink-0 relative">
              <%= if photo = Map.get(@avatar_photos, conv.other_user && conv.other_user.id) do %>
                <img
                  src={Photos.signed_url(photo)}
                  class="w-10 h-10 rounded-full object-cover"
                  alt=""
                />
              <% else %>
                <div class="w-10 h-10 rounded-full bg-base-200 flex items-center justify-center">
                  <.icon name="hero-user" class="h-5 w-5 text-base-content/30" />
                </div>
              <% end %>
              <span
                :if={conv.unread}
                class="absolute -top-0.5 -right-0.5 w-3 h-3 rounded-full bg-error border-2 border-base-100"
              >
              </span>
            </div>

            <%!-- Content --%>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between">
                <p class={[
                  "text-sm truncate",
                  if(conv.unread, do: "font-semibold", else: "font-medium")
                ]}>
                  {conv.other_user && conv.other_user.display_name}
                </p>
                <span
                  :if={conv.latest_message}
                  class="text-xs text-base-content/40 flex-shrink-0 ml-2"
                >
                  {format_time(conv.latest_message.inserted_at)}
                </span>
              </div>
              <p :if={conv.latest_message} class="text-xs text-base-content/50 truncate">
                {String.slice(conv.latest_message.content || "", 0, 50)}
              </p>
            </div>
          </.link>
        </div>

        <%!-- Footer link --%>
        <div class="p-3 border-t border-base-300">
          <.link navigate={~p"/my/messages"} class="btn btn-ghost btn-sm w-full">
            {gettext("All messages")}
            <.icon name="hero-arrow-right-mini" class="h-4 w-4" />
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    now = Animina.TimeMachine.utc_now()
    diff_hours = DateTime.diff(now, datetime, :hour)

    cond do
      diff_hours < 1 ->
        diff_min = DateTime.diff(now, datetime, :minute)
        if diff_min < 1, do: gettext("now"), else: "#{diff_min}m"

      diff_hours < 24 ->
        "#{diff_hours}h"

      true ->
        diff_days = div(diff_hours, 24)
        "#{diff_days}d"
    end
  end
end
