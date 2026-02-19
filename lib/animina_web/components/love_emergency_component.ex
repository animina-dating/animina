defmodule AniminaWeb.LoveEmergencyComponent do
  @moduledoc """
  LiveComponent for the Love Emergency flow.

  Allows users to reopen a closed conversation by selecting
  exactly N active conversations to close (configurable via feature flags).
  """

  use AniminaWeb, :live_component

  alias Animina.Messaging
  alias AniminaWeb.Helpers.AvatarHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div class="bg-base-100 rounded-lg p-6 max-w-lg mx-4 shadow-xl max-h-[80vh] overflow-y-auto">
        <div class="flex items-center gap-2 mb-2">
          <.icon name="hero-heart" class="h-6 w-6 text-error" />
          <h3 class="text-lg font-semibold">{gettext("Love Emergency")}</h3>
        </div>

        <p class="text-base-content/70 text-sm mb-4">
          {gettext(
            "To reopen this conversation, you must let go of %{cost} active conversations. Select exactly %{cost} below.",
            cost: @cost
          )}
        </p>

        <div class="space-y-2 mb-6">
          <div
            :for={conv <- @active_conversations}
            class={[
              "flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors",
              if(MapSet.member?(@selected, conv.conversation.id),
                do: "border-error bg-error/5",
                else: "border-base-300 hover:bg-base-200"
              )
            ]}
            phx-click="toggle_selection"
            phx-value-conversation-id={conv.conversation.id}
            phx-target={@myself}
          >
            <.user_avatar user={conv.other_user} photos={@avatar_photos} size={:sm} />
            <div class="flex-1 min-w-0">
              <div class="font-medium truncate">{conv.other_user.display_name}</div>
            </div>
            <div class="flex-shrink-0">
              <%= if MapSet.member?(@selected, conv.conversation.id) do %>
                <.icon name="hero-check-circle-solid" class="h-6 w-6 text-error" />
              <% else %>
                <.icon name="hero-minus-circle" class="h-6 w-6 text-base-content/20" />
              <% end %>
            </div>
          </div>
        </div>

        <div class="text-sm text-base-content/50 mb-4 text-center">
          {gettext("%{selected}/%{cost} selected",
            selected: MapSet.size(@selected),
            cost: @cost
          )}
        </div>

        <div class="flex gap-3 justify-end">
          <button phx-click="cancel_love_emergency" phx-target={@myself} class="btn btn-ghost btn-sm">
            {gettext("Cancel")}
          </button>
          <button
            phx-click="confirm_love_emergency"
            phx-target={@myself}
            class={[
              "btn btn-error btn-sm",
              MapSet.size(@selected) != @cost && "btn-disabled"
            ]}
            disabled={MapSet.size(@selected) != @cost}
          >
            <.icon name="hero-heart" class="h-4 w-4" />
            {gettext("Reopen Conversation")}
          </button>
        </div>
      </div>
    </div>
    """
  end


  @impl true
  def update(assigns, socket) do
    active_conversations = assigns[:active_conversations] || []

    # Load avatars for all conversation users
    all_users = Enum.map(active_conversations, & &1.other_user) |> Enum.reject(&is_nil/1)
    avatar_photos = AvatarHelpers.load_from_users(all_users)

    socket =
      socket
      |> assign(:conversation_id_to_reopen, assigns[:conversation_id_to_reopen])
      |> assign(:current_user_id, assigns[:current_user_id])
      |> assign(:active_conversations, active_conversations)
      |> assign(:cost, assigns[:cost] || 4)
      |> assign(:avatar_photos, avatar_photos)
      |> assign_new(:selected, fn -> MapSet.new() end)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_selection", %{"conversation-id" => conv_id}, socket) do
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, conv_id) do
        MapSet.delete(selected, conv_id)
      else
        if MapSet.size(selected) < socket.assigns.cost do
          MapSet.put(selected, conv_id)
        else
          selected
        end
      end

    {:noreply, assign(socket, :selected, selected)}
  end

  @impl true
  def handle_event("confirm_love_emergency", _params, socket) do
    selected = socket.assigns.selected
    cost = socket.assigns.cost

    if MapSet.size(selected) == cost do
      close_ids = MapSet.to_list(selected)

      case Messaging.love_emergency_reopen(
             socket.assigns.current_user_id,
             socket.assigns.conversation_id_to_reopen,
             close_ids
           ) do
        {:ok, _} ->
          send(self(), {:love_emergency_complete, socket.assigns.conversation_id_to_reopen})
          {:noreply, socket}

        {:error, reason} ->
          send(self(), {:love_emergency_error, reason})
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_love_emergency", _params, socket) do
    send(self(), :love_emergency_cancelled)
    {:noreply, socket}
  end
end
