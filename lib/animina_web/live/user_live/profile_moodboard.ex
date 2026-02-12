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
  alias Animina.Accounts.OnlineActivity
  alias Animina.Accounts.Scope
  alias Animina.Discovery
  alias Animina.Discovery.Spotlight
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Moodboard
  alias Animina.Reports
  alias Animina.Traits
  alias AniminaWeb.ColumnToggle
  alias AniminaWeb.Helpers.ColumnPreferences
  alias AniminaWeb.Presence

  @impl true
  def render(%{access_restricted: true} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li><.link navigate={~p"/my/spotlight"}>{gettext("Spotlight")}</.link></li>
            <li>{@profile_user.display_name}</li>
          </ul>
        </div>

        <div class="card bg-base-100 shadow-lg border border-base-300">
          <div class="card-body text-center py-12">
            <div class="mx-auto mb-4">
              <div class="w-24 h-24 rounded-full bg-base-200 flex items-center justify-center mx-auto">
                <.icon name="hero-user" class="h-12 w-12 text-base-content/30" />
              </div>
            </div>

            <h2 class="text-2xl font-bold">{@profile_user.display_name}</h2>
            <p class="text-base-content/60">
              {gettext("%{age} years", age: @age)}
              <%= if @profile_user.height do %>
                · {format_height(@profile_user.height)}
              <% end %>
              <%= if @city do %>
                · {@city.name}
              <% end %>
            </p>

            <div class="divider"></div>

            <div class="alert alert-info">
              <.icon name="hero-lock-closed" class="h-5 w-5" />
              <span>
                {gettext(
                  "This profile is only visible when you appear in each other's Daily Spotlight or have an active conversation."
                )}
              </span>
            </div>

            <div class="mt-4">
              <.link navigate={~p"/my/spotlight"} class="btn btn-primary">
                <.icon name="hero-sparkles" class="h-5 w-5 mr-2" />
                {gettext("Back to Spotlight")}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

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
                · <span class="whitespace-nowrap">{@city.name}</span>
              <% end %>
            </p>
            <p :if={@profile_user.occupation} class="text-base-content/60">
              {@profile_user.occupation}
            </p>
            <p
              :if={!@owner? && !@hide_online_status}
              class="text-base-content/60 flex items-center gap-1.5 flex-wrap"
            >
              <%= if @is_online do %>
                <span class="inline-block w-2.5 h-2.5 rounded-full bg-success"></span>
                <span class="font-medium text-success">{gettext("Online")}</span>
              <% else %>
                <span class="inline-block w-2.5 h-2.5 rounded-full bg-base-content/30"></span>
                <span>{format_last_seen(@last_seen_at)}</span>
              <% end %>
              <%= if @activity_level_text do %>
                <span class="text-base-content/30">&middot;</span>
                <span>{@activity_level_text}</span>
              <% end %>
              <%= if @typical_times_text do %>
                <span class="text-base-content/30">&middot;</span>
                <span>{@typical_times_text}</span>
              <% end %>
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

            <button
              :if={!@owner? && @current_scope.user}
              phx-click="open_report_modal"
              class="btn btn-ghost btn-sm text-error/60 hover:text-error"
              title={gettext("Report user")}
            >
              <.icon name="hero-flag" class="h-4 w-4" />
            </button>

            <.link
              :if={@owner?}
              navigate={~p"/my/settings/profile/moodboard"}
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
          
    <!-- Moodboard grid using CSS columns for balanced height distribution -->
          <div class={moodboard_columns_class(@columns)}>
            <%= for item <- @items do %>
              <div class="break-inside-avoid mb-4 md:mb-5 lg:mb-6">
                <.live_component
                  module={AniminaWeb.LiveMoodboardItemComponent}
                  id={"moodboard-item-#{item.id}"}
                  item={item}
                  owner?={@owner?}
                />
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

      <.live_component
        :if={@show_report_modal}
        module={AniminaWeb.ReportModalComponent}
        id="report-modal"
        show={@show_report_modal}
        reported_user={@profile_user}
        context_type="profile"
        context_id={nil}
        current_scope={@current_scope}
      />
    </Layouts.app>
    """
  end

  # Build page title with profile info: Display Name · ♀ 32 Jahre · 1,72 m · 56068 Koblenz
  defp resolve_chat_state(current_user_id, profile_user_id) do
    case Messaging.get_conversation_by_participants(current_user_id, profile_user_id) do
      nil ->
        case Messaging.can_initiate_conversation?(current_user_id, profile_user_id) do
          :ok -> {nil, nil}
          {:error, reason} -> {nil, reason}
        end

      conversation ->
        {conversation.id, nil}
    end
  end

  defp build_page_title(user, age, city) do
    parts = [
      user.display_name,
      gender_symbol(user.gender) <> " " <> gettext("%{age} years", age: age),
      if(user.height, do: format_height(user.height)),
      if(city, do: city.name)
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

  defp compute_online_assigns(socket, profile_user, owner?) do
    is_online = Presence.user_online?(profile_user.id)
    viewer_is_privileged = Scope.moderator?(socket.assigns.current_scope)
    hide_online_status = profile_user.hide_online_status && !viewer_is_privileged

    if owner? || hide_online_status do
      {is_online, hide_online_status, nil, nil, nil}
    else
      last_seen = unless is_online, do: Accounts.last_seen(profile_user.id)
      al = Accounts.activity_level(profile_user.id)
      tt = Accounts.typical_online_times(profile_user.id)

      {is_online, hide_online_status, last_seen, OnlineActivity.activity_level_label(al),
       OnlineActivity.typical_times_label(tt)}
    end
  end

  # Format relative time for "last seen" display
  defp format_last_seen(nil), do: gettext("Offline")

  defp format_last_seen(datetime) do
    now = Animina.TimeMachine.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)
    diff_minutes = div(diff_seconds, 60)
    diff_hours = div(diff_minutes, 60)
    diff_days = div(diff_hours, 24)

    cond do
      diff_minutes < 5 ->
        gettext("Just now")

      diff_minutes < 60 ->
        ngettext(
          "Online %{count} minute ago",
          "Online %{count} minutes ago",
          diff_minutes
        )

      diff_hours < 24 ->
        ngettext(
          "Online %{count} hour ago",
          "Online %{count} hours ago",
          diff_hours
        )

      diff_days <= 7 ->
        ngettext(
          "Online %{count} day ago",
          "Online %{count} days ago",
          diff_days
        )

      true ->
        gettext("Online more than a week ago")
    end
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

      {:access_restricted, profile_user} ->
        {:ok, mount_minimal_profile(socket, profile_user)}

      :denied ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This page doesn't exist or you don't have access."))
         |> redirect(to: ~p"/")}
    end
  end

  defp check_access(current_user, profile_user, current_scope) do
    owner? = current_user && profile_user && current_user.id == profile_user.id

    cond do
      is_nil(profile_user) ->
        :denied

      owner? ->
        {:ok, true}

      is_nil(current_user) ->
        :denied

      # Report invisibility check — mutually hidden users can't see each other
      Reports.hidden?(current_user.id, profile_user.id) ->
        :denied

      Spotlight.has_moodboard_access?(current_user, profile_user, current_scope) ->
        {:ok, false}

      true ->
        {:access_restricted, profile_user}
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
    page_title = build_page_title(profile_user, age, city)

    # Chat panel assigns
    show_chat_toggle = !owner? && current_user != nil

    {chat_conversation_id, chat_blocked_reason} =
      if show_chat_toggle do
        resolve_chat_state(current_user.id, profile_user.id)
      else
        {nil, nil}
      end

    # Online activity assigns
    {is_online, hide_online_status, last_seen_at, activity_level_text, typical_times_text} =
      compute_online_assigns(socket, profile_user, owner?)

    initial_columns =
      if owner?,
        do: ColumnPreferences.get_columns_for_user(current_user),
        else: ColumnPreferences.default_columns()

    assign(socket,
      page_title: page_title,
      profile_user: profile_user,
      owner?: owner?,
      access_restricted: false,
      items: items,
      current_user_id: current_user.id,
      columns: initial_columns,
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
      wildcard?: false,
      is_online: is_online,
      last_seen_at: last_seen_at,
      hide_online_status: hide_online_status,
      activity_level_text: activity_level_text,
      typical_times_text: typical_times_text,
      show_report_modal: false
    )
  end

  defp mount_minimal_profile(socket, profile_user) do
    age = Accounts.compute_age(profile_user.birthday)
    locations = Accounts.list_user_locations(profile_user)
    primary_location = Enum.find(locations, &(&1.position == 1))

    city =
      if primary_location do
        GeoData.get_city_by_zip_code(primary_location.zip_code)
      end

    assign(socket,
      page_title: profile_user.display_name,
      profile_user: profile_user,
      owner?: false,
      access_restricted: true,
      age: age,
      city: city,
      # Dummy assigns required by handle_params and render
      items: [],
      columns: 1,
      zip_code: nil,
      white_flags: [],
      private_white_flags_count: 0,
      show_chat_toggle: false,
      chat_blocked_reason: nil,
      chat_open: false,
      chat_conversation_id: nil,
      chat_subscribed: false,
      chat_typing_timer: nil,
      wildcard?: false,
      current_user_id: socket.assigns.current_scope.user.id,
      is_online: false,
      last_seen_at: nil,
      hide_online_status: true,
      activity_level_text: nil,
      typical_times_text: nil
    )
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :wildcard?, params["ref"] == "wildcard")}
  end

  @impl true
  def handle_event("device_type_detected", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_report_modal", _params, socket) do
    {:noreply, assign(socket, :show_report_modal, true)}
  end

  @impl true
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :show_report_modal, false)}
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
    if socket.assigns.owner? do
      {columns, updated_user} =
        ColumnPreferences.persist_columns(
          socket.assigns.current_scope.user,
          columns_str
        )

      {:noreply,
       socket
       |> assign(:columns, columns)
       |> ColumnPreferences.update_scope_user(updated_user)}
    else
      {:noreply, assign(socket, :columns, String.to_integer(columns_str))}
    end
  end

  @impl true
  def handle_event("love_emergency_from_profile", _params, socket) do
    profile_user = socket.assigns.profile_user
    {:noreply, push_navigate(socket, to: ~p"/my/messages?love_emergency_for=#{profile_user.id}")}
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
  def handle_info({:report_submitted, _reported_user_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_report_modal, false)
     |> put_flash(:info, gettext("Report submitted. Our team will review it."))
     |> redirect(to: ~p"/my/spotlight")}
  end

  @impl true
  def handle_info({:report_failed}, socket) do
    {:noreply,
     socket
     |> assign(:show_report_modal, false)
     |> put_flash(:error, gettext("Could not submit report. Please try again."))}
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

  defp moodboard_columns_class(1), do: "pt-6"
  defp moodboard_columns_class(2), do: "columns-2 gap-4 md:gap-5 lg:gap-6 pt-6"
  defp moodboard_columns_class(3), do: "columns-3 gap-4 md:gap-5 lg:gap-6 pt-6"

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
