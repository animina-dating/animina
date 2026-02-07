defmodule AniminaWeb.UserLive.ProfileMoodboard do
  @moduledoc """
  LiveView for displaying a user's moodboard.

  Features:
  - Editorial magazine-style Pinterest masonry layout
  - Three item types: photo cards, quote cards, combined cards
  - Soft shadows and premium visual polish
  - Owner view shows hidden items with status
  - Column preferences persisted per device type
  - Real-time updates via PubSub subscriptions
  """

  use AniminaWeb, :live_view

  import AniminaWeb.Helpers.UserHelpers, only: [gender_icon: 1, gender_symbol: 1]

  alias Animina.Accounts
  alias Animina.Discovery
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Moodboard
  alias Animina.Traits
  alias AniminaWeb.ColumnToggle

  import AniminaWeb.MoodboardComponents, only: [distribute_to_columns: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="moodboard-container"
        phx-hook="DeviceType"
        class={[
          if(@chat_open,
            do: "lg:mr-[396px] transition-all duration-300",
            else: "transition-all duration-300"
          )
        ]}
      >
        <!-- Wildcard notice -->
        <div
          :if={@wildcard?}
          class="flex items-center gap-3 rounded-lg border-2 border-dashed border-accent/40 bg-accent/5 px-4 py-3 mb-6"
        >
          <.icon name="hero-bolt" class="h-5 w-5 text-accent flex-shrink-0" />
          <p class="text-sm text-base-content/70">
            <span class="font-semibold text-accent">{gettext("Wildcard pick")}</span>
            — {gettext("This profile was suggested randomly and may not match your preferences.")}
          </p>
        </div>
        
    <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold">{@profile_user.display_name}</h1>
            <p class="text-base-content/60">
              <span>{gender_icon(@profile_user.gender)}</span>
              {gettext("%{age} years", age: @age)}
              <%= if @profile_user.height do %>
                · {format_height(@profile_user.height)}
              <% end %>
              <%= if @city do %>
                · <span class="whitespace-nowrap">{@zip_code} {@city.name}</span>
              <% end %>
            </p>
            <p :if={@profile_user.occupation} class="text-base-content/60">
              {@profile_user.occupation}
            </p>
          </div>

          <div class="flex items-center gap-2">
            <%= if @show_chat_toggle && @chat_blocked_reason == nil do %>
              <button
                phx-click="toggle_chat"
                class={["btn", if(@chat_open, do: "btn-primary", else: "btn-outline btn-primary")]}
              >
                <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 mr-2" />
                {gettext("Message")}
              </button>
            <% end %>
            <%= if @show_chat_toggle && @chat_blocked_reason == :chat_slots_full do %>
              <span
                class="btn btn-outline btn-disabled opacity-50"
                title={gettext("No free chat slots")}
              >
                <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 mr-2" />
                {gettext("No free slots")}
              </span>
            <% end %>
            <%= if @show_chat_toggle && @chat_blocked_reason == :previously_closed do %>
              <button
                phx-click="love_emergency_from_profile"
                class="btn btn-outline btn-error"
              >
                <.icon name="hero-heart" class="h-5 w-5 mr-2" />
                {gettext("Reopen")}
              </button>
            <% end %>

            <.link
              :if={@owner?}
              navigate={~p"/users/settings/moodboard"}
              class="btn btn-primary"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-2"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
              {gettext("Edit Moodboard")}
            </.link>
          </div>
        </div>
        
    <!-- White flags display -->
        <div :if={length(@white_flags) > 0 || @private_white_flags_count > 0} class="mb-8">
          <div class="flex flex-wrap gap-1.5 sm:gap-3">
            <%= for {category_name, flags} <- group_flags_by_category(@white_flags) do %>
              <div class="inline-flex items-center gap-1 sm:gap-2 bg-base-100 rounded-xl sm:rounded-2xl px-2 sm:px-4 py-1.5 sm:py-2.5 shadow-[0_2px_8px_-2px_rgba(0,0,0,0.08)] border border-base-200/80">
                <span class="text-[10px] sm:text-xs font-medium text-base-content/40 uppercase tracking-wide shrink-0">
                  {AniminaWeb.TraitTranslations.translate(category_name)}
                </span>
                <div class="flex flex-wrap items-center gap-1 sm:gap-2">
                  <%= for user_flag <- flags do %>
                    <span class="inline-flex items-center gap-0.5 sm:gap-1 text-xs sm:text-sm bg-base-200/50 rounded-lg px-1.5 sm:px-2 py-0.5 max-w-[120px] sm:max-w-[180px]">
                      <span class="shrink-0">{user_flag.flag.emoji}</span>
                      <span class="text-base-content/80 truncate">
                        {AniminaWeb.TraitTranslations.translate(user_flag.flag.name)}
                      </span>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
            <div
              :if={@private_white_flags_count > 0}
              class="inline-flex items-center gap-1 sm:gap-1.5 bg-base-200/30 rounded-xl sm:rounded-2xl px-2 sm:px-4 py-1.5 sm:py-2.5 text-base-content/40 text-xs sm:text-sm border border-dashed border-base-300"
              title={gettext("Private flags not shown on profile")}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
                />
              </svg>
              <span>+{@private_white_flags_count} {gettext("private")}</span>
            </div>
          </div>
        </div>
        
    <!-- Empty state -->
        <div :if={Enum.empty?(@items)} class="text-center py-16">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-16 w-16 mx-auto text-base-content/30 mb-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1.5"
              d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
          <h2 class="text-xl font-semibold text-base-content/60">
            {gettext("No moodboard items yet")}
          </h2>
          <p :if={@owner?} class="text-base-content/50 mt-2">
            {gettext("Add photos and text to your moodboard to share with others.")}
          </p>
        </div>
        
    <!-- Editorial moodboard with real-time updates -->
        <div :if={!Enum.empty?(@items)}>
          <ColumnToggle.column_toggle columns={@columns} />
          
    <!-- Moodboard grid using Flexbox columns -->
          <div class={[
            "flex gap-4 md:gap-5 lg:gap-6 pt-6",
            if(@columns == 1, do: "flex-col", else: "flex-row")
          ]}>
            <%= for {column_items, col_idx} <- distribute_to_columns(@items, column_count(@columns)) do %>
              <div class="flex-1 flex flex-col gap-4 md:gap-5 lg:gap-6">
                <%= for item <- column_items do %>
                  <div>
                    <.live_component
                      module={AniminaWeb.LiveMoodboardItemComponent}
                      id={"moodboard-item-#{item.id}"}
                      item={item}
                      owner?={@owner?}
                    />
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <.live_component
        :if={@show_chat_toggle}
        module={AniminaWeb.ChatPanelComponent}
        id="chat-panel"
        current_user_id={@current_user_id}
        profile_user={@profile_user}
        open={@chat_open}
        conversation_id={@chat_conversation_id}
      />
    </Layouts.app>
    """
  end

  # Return the column count (validated to 1, 2, or 3)
  defp column_count(columns) when columns in [1, 2, 3], do: columns
  defp column_count(_), do: 2

  # Build page title with profile info: Display Name · ♀ 32 Jahre · 1,72 m · 56068 Koblenz
  defp build_page_title(user, age, city, zip_code) do
    parts = [
      user.display_name,
      gender_symbol(user.gender) <> " " <> gettext("%{age} years", age: age),
      if(user.height, do: format_height(user.height)),
      if(city, do: "#{zip_code}\u00A0#{city.name}")
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  # Format height from cm to meters with comma decimal separator (172 -> "1,72 m")
  defp format_height(height_cm) do
    meters = height_cm / 100
    formatted = :erlang.float_to_binary(meters, decimals: 2)
    String.replace(formatted, ".", ",") <> " m"
  end

  # Group white flags by their category name, preserving order
  defp group_flags_by_category(white_flags) do
    white_flags
    |> Enum.group_by(& &1.flag.category.name)
    |> Enum.sort_by(fn {_name, flags} ->
      # Sort by the first flag's category position (flags are already ordered by category)
      hd(flags).flag.category.position
    end)
  end

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    current_scope = socket.assigns.current_scope
    current_user = current_scope && current_scope.user
    profile_user = Accounts.get_user(user_id)

    case check_access(current_user, profile_user, current_scope) do
      {:ok, owner?} ->
        # Record profile visit (only if not viewing own profile)
        if !owner? && current_user do
          Discovery.record_profile_visit(current_user.id, profile_user.id)
        end

        {:ok, mount_moodboard(socket, profile_user, current_user, owner?)}

      :denied ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This page doesn't exist or you don't have access."))
         |> redirect(to: ~p"/")}
    end
  end

  defp check_access(current_user, profile_user, _current_scope) do
    owner? = current_user && profile_user && current_user.id == profile_user.id

    cond do
      is_nil(profile_user) -> :denied
      owner? -> {:ok, true}
      current_user != nil -> {:ok, false}
      true -> :denied
    end
  end

  defp mount_moodboard(socket, profile_user, current_user, owner?) do
    items = Moodboard.list_moodboard_with_hidden(profile_user.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "moodboard:#{profile_user.id}")
    end

    # Compute age
    age = Accounts.compute_age(profile_user.birthday)

    # Get primary location (position 1) with city name
    locations = Accounts.list_user_locations(profile_user)
    primary_location = Enum.find(locations, &(&1.position == 1))

    {city, zip_code} =
      if primary_location do
        {GeoData.get_city_by_zip_code(primary_location.zip_code), primary_location.zip_code}
      else
        {nil, nil}
      end

    # Get published white flags for display
    white_flags = Traits.list_published_white_flags(profile_user)
    private_white_flags_count = Traits.count_private_white_flags(profile_user)

    # Build page title with profile info
    page_title = build_page_title(profile_user, age, city, zip_code)

    # Chat panel assigns
    show_chat_toggle = !owner? && current_user != nil

    {chat_conversation_id, chat_blocked_reason} =
      if show_chat_toggle do
        case Messaging.get_conversation_by_participants(current_user.id, profile_user.id) do
          nil ->
            # No existing conversation — check if we can start one
            case Messaging.can_initiate_conversation?(current_user.id, profile_user.id) do
              :ok -> {nil, nil}
              {:error, reason} -> {nil, reason}
            end

          conversation ->
            {conversation.id, nil}
        end
      else
        {nil, nil}
      end

    assign(socket,
      page_title: page_title,
      profile_user: profile_user,
      owner?: owner?,
      items: items,
      current_user_id: current_user.id,
      device_type: "desktop",
      columns: 3,
      age: age,
      city: city,
      zip_code: zip_code,
      white_flags: white_flags,
      private_white_flags_count: private_white_flags_count,
      show_chat_toggle: show_chat_toggle,
      chat_blocked_reason: chat_blocked_reason,
      chat_open: false,
      chat_conversation_id: chat_conversation_id,
      chat_subscribed: false,
      chat_typing_timer: nil,
      wildcard?: false
    )
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :wildcard?, params["ref"] == "wildcard")}
  end

  @impl true
  def handle_event("device_type_detected", %{"device_type" => device_type}, socket) do
    # Load column preference for this device type from user's preferences
    columns = get_columns_for_device(socket, device_type)
    {:noreply, assign(socket, device_type: device_type, columns: columns)}
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    chat_open = !socket.assigns.chat_open

    socket =
      if chat_open && !socket.assigns.chat_subscribed && socket.assigns.chat_conversation_id do
        subscribe_to_chat(socket, socket.assigns.chat_conversation_id)
      else
        socket
      end

    {:noreply, assign(socket, :chat_open, chat_open)}
  end

  @impl true
  def handle_event("close_panel", _params, socket) do
    {:noreply, assign(socket, :chat_open, false)}
  end

  @impl true
  def handle_event("save_draft", %{"content" => content}, socket) do
    if socket.assigns.chat_conversation_id && socket.assigns.current_scope.user do
      Animina.Messaging.save_draft(
        socket.assigns.chat_conversation_id,
        socket.assigns.current_scope.user.id,
        content
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    columns = String.to_integer(columns_str)

    # Save preference if owner is logged in
    if socket.assigns.owner? do
      user = socket.assigns.current_scope.user
      device_type = socket.assigns.device_type
      Accounts.update_moodboard_columns(user, device_type, columns)
    end

    {:noreply, assign(socket, :columns, columns)}
  end

  @impl true
  def handle_event("love_emergency_from_profile", _params, socket) do
    profile_user = socket.assigns.profile_user
    {:noreply, push_navigate(socket, to: ~p"/messages?love_emergency_for=#{profile_user.id}")}
  end

  defp get_columns_for_device(socket, device_type) do
    if socket.assigns.owner? do
      get_user_columns(socket.assigns.current_scope.user, device_type)
    else
      get_default_columns(device_type)
    end
  end

  defp get_user_columns(user, device_type) do
    case device_type do
      "mobile" -> user.moodboard_columns_mobile || 2
      "tablet" -> user.moodboard_columns_tablet || 2
      "desktop" -> user.moodboard_columns_desktop || 3
      _ -> 2
    end
  end

  defp get_default_columns(device_type) do
    case device_type do
      "mobile" -> 2
      "tablet" -> 2
      "desktop" -> 3
      _ -> 2
    end
  end

  # Handle moodboard PubSub messages - all trigger a reload
  @impl true
  def handle_info({event, _payload}, socket)
      when event in [
             :moodboard_item_created,
             :moodboard_item_deleted,
             :moodboard_item_updated,
             :moodboard_positions_updated,
             :story_updated
           ] do
    {:noreply, reload_items(socket)}
  end

  # Handle white flag updates
  @impl true
  def handle_info({:white_flags_updated, _payload}, socket) do
    {:noreply, reload_white_flags(socket)}
  end

  # --- Chat panel PubSub forwarding ---

  @impl true
  def handle_info({:chat_panel_subscribe, conversation_id}, socket) do
    socket =
      socket
      |> assign(:chat_conversation_id, conversation_id)
      |> subscribe_to_chat(conversation_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_chat_panel, socket) do
    {:noreply, assign(socket, :chat_open, false)}
  end

  # Conversation-specific PubSub (2-tuple) — forward to ChatPanelComponent
  @impl true
  def handle_info({:new_message, %{__struct__: _} = message}, socket) do
    send_update(AniminaWeb.ChatPanelComponent,
      id: "chat-panel",
      chat_event: {:new_message, message}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_edited, message}, socket) do
    send_update(AniminaWeb.ChatPanelComponent,
      id: "chat-panel",
      chat_event: {:message_edited, message}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_deleted, message}, socket) do
    send_update(AniminaWeb.ChatPanelComponent,
      id: "chat-panel",
      chat_event: {:message_deleted, message}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:read_receipt, user_id}, socket) do
    send_update(AniminaWeb.ChatPanelComponent,
      id: "chat-panel",
      chat_event: {:read_receipt, user_id}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing, user_id, typing?}, socket) do
    if user_id != socket.assigns.current_user_id do
      # Cancel existing timer
      if socket.assigns.chat_typing_timer do
        Process.cancel_timer(socket.assigns.chat_typing_timer)
      end

      if typing? do
        timer = Process.send_after(self(), :clear_chat_typing, 3_000)

        send_update(AniminaWeb.ChatPanelComponent,
          id: "chat-panel",
          chat_event: {:typing, user_id}
        )

        {:noreply, assign(socket, :chat_typing_timer, timer)}
      else
        send_update(AniminaWeb.ChatPanelComponent,
          id: "chat-panel",
          chat_event: :clear_typing
        )

        {:noreply, assign(socket, :chat_typing_timer, nil)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_chat_typing, socket) do
    send_update(AniminaWeb.ChatPanelComponent,
      id: "chat-panel",
      chat_event: :clear_typing
    )

    {:noreply, assign(socket, :chat_typing_timer, nil)}
  end

  @impl true
  def handle_info({:chat_panel_error, msg}, socket) do
    {:noreply, put_flash(socket, :error, msg)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp subscribe_to_chat(socket, conversation_id) do
    if connected?(socket) && !socket.assigns.chat_subscribed do
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.conversation_topic(conversation_id))
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.typing_topic(conversation_id))
      assign(socket, :chat_subscribed, true)
    else
      socket
    end
  end

  defp reload_items(socket) do
    items = Moodboard.list_moodboard_with_hidden(socket.assigns.profile_user.id)
    assign(socket, :items, items)
  end

  defp reload_white_flags(socket) do
    profile_user = socket.assigns.profile_user
    white_flags = Traits.list_published_white_flags(profile_user)
    private_white_flags_count = Traits.count_private_white_flags(profile_user)

    assign(socket,
      white_flags: white_flags,
      private_white_flags_count: private_white_flags_count
    )
  end
end
