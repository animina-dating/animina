defmodule AniminaWeb.UserLive.MyHub do
  @moduledoc """
  Personal hub LiveView with two modes:

  - **Hub mode** (profile <5/6 complete or waitlisted) — navigation cards + setup shortcuts
  - **Dashboard mode** (profile ≥5/6 complete) — embedded spotlight grid + conversations + chat panel
  """

  use AniminaWeb, :live_view

  import AniminaWeb.SpotlightComponents
  import AniminaWeb.WaitlistComponents

  alias Animina.Discovery
  alias Animina.Discovery.Spotlight
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Moodboard
  alias AniminaWeb.Helpers.AvatarHelpers
  alias AniminaWeb.Helpers.ColumnPreferences
  alias AniminaWeb.Helpers.WaitlistData

  @dashboard_threshold 5
  @countdown_interval :timer.minutes(1)

  # --- Render ---

  @impl true
  def render(%{mode: :dashboard} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <h1 class="text-2xl font-semibold text-base-content">
            {gettext("Hey %{name}!", name: @user.display_name)}
          </h1>
        </div>

        <%!-- Unread conversations section --%>
        <div :if={@unread_conversations != []} class="space-y-3">
          <h2 class="text-lg font-semibold flex items-center gap-2">
            <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 text-primary" />
            {ngettext(
              "%{count} unread conversation",
              "%{count} unread conversations",
              length(@unread_conversations),
              count: length(@unread_conversations)
            )}
          </h2>

          <div class="space-y-1">
            <.conversation_row
              :for={conv <- @unread_conversations}
              conversation={conv}
              avatar_photos={@conversation_avatars}
              online_user_ids={@online_user_ids}
              current_scope={@current_scope}
              unread={true}
            />
          </div>
        </div>

        <%!-- Spotlight section --%>
        <div>
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold flex items-center gap-2">
              <.icon name="hero-sparkles" class="h-5 w-5 text-accent" />
              {gettext("Daily Spotlight")}
            </h2>
            <span class="text-sm text-base-content/50">
              {gettext("New profiles in %{time}", time: @countdown_text)}
            </span>
          </div>

          <div :if={@loading_spotlight} class="flex justify-center py-8">
            <span class="loading loading-spinner loading-lg text-primary"></span>
          </div>

          <div :if={!@loading_spotlight}>
            <div :if={@candidates == []} class="text-center py-8 text-base-content/50">
              <.icon name="hero-magnifying-glass" class="h-10 w-10 mx-auto mb-2 opacity-40" />
              <p class="text-sm">
                {gettext("No candidates found. Try adjusting your search settings.")}
              </p>
            </div>

            <div :if={@candidates != []} class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
              <.spotlight_card
                :for={candidate <- @candidates}
                candidate={candidate}
                avatar={Map.get(@avatar_photos, candidate.id)}
                city_name={city_name_for(candidate, @city_names)}
                story_excerpt={Map.get(@first_stories, candidate.id)}
                wildcard?={MapSet.member?(@wildcard_ids, candidate.id)}
                visited?={MapSet.member?(@visited_ids, candidate.id)}
              />
            </div>
          </div>
        </div>

        <%!-- Conversations summary (when no unread) --%>
        <div
          :if={@unread_conversations == []}
          class="flex items-center justify-between py-3 border-t border-base-300"
        >
          <span class="text-sm text-base-content/50 flex items-center gap-2">
            <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
            {ngettext(
              "%{count} conversation",
              "%{count} conversations",
              @total_conversation_count,
              count: @total_conversation_count
            )}
          </span>
          <.link navigate={~p"/my/messages"} class="text-sm text-primary hover:underline">
            {gettext("All messages")}
          </.link>
        </div>

        <%!-- Read conversations (when unread exist, show all conversations link below) --%>
        <div
          :if={@unread_conversations != []}
          class="flex items-center justify-between py-3 border-t border-base-300"
        >
          <span class="text-sm text-base-content/50">
            {ngettext(
              "%{count} conversation total",
              "%{count} conversations total",
              @total_conversation_count,
              count: @total_conversation_count
            )}
          </span>
          <.link navigate={~p"/my/messages"} class="text-sm text-primary hover:underline">
            {gettext("All messages")}
          </.link>
        </div>
      </div>

      <%!-- Chat panel --%>
      <.live_component
        :if={@chat_profile_user}
        module={AniminaWeb.ChatPanelComponent}
        id="chat-panel"
        current_user_id={@user.id}
        profile_user={@chat_profile_user}
        open={@chat_open}
        conversation_id={@chat_conversation_id}
      />
    </Layouts.app>
    """
  end

  def render(%{mode: :hub} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="max-w-2xl mx-auto">
          <h1 class="text-2xl font-semibold text-base-content">
            {gettext("Hey %{name}!", name: @user.display_name)}
          </h1>

          <%= if @profile_completeness.completed_count < @profile_completeness.total_count do %>
            <div class="mt-3">
              <div class="flex items-center justify-between text-sm text-base-content/60 mb-1">
                <span>
                  {gettext("Profile progress")}
                </span>
                <span>
                  {@profile_completeness.completed_count}/{@profile_completeness.total_count}
                </span>
              </div>
              <progress
                class="progress progress-primary w-full"
                value={@profile_completeness.completed_count}
                max={@profile_completeness.total_count}
              >
              </progress>
            </div>
          <% end %>
        </div>

        <%= if @user.state == "waitlisted" do %>
          <.waitlist_status_banner
            end_waitlist_at={@end_waitlist_at}
            current_scope={@current_scope}
          />
        <% else %>
          <div class="grid gap-3 grid-cols-1 sm:grid-cols-2">
            <.hub_card
              navigate={~p"/my/messages"}
              icon="hero-chat-bubble-left-right"
              title={gettext("Messages")}
              subtitle={gettext("Your conversations")}
            />
            <.hub_card
              navigate={~p"/my/spotlight"}
              icon="hero-sparkles"
              title={gettext("Spotlight")}
              subtitle={gettext("Find new people")}
            />
          </div>
        <% end %>

        <.waitlist_preparation_section
          columns={@columns}
          profile_completeness={@profile_completeness}
          avatar_photo={@avatar_photo}
          flag_count={@flag_count}
          moodboard_count={@moodboard_count}
          has_passkeys={@has_passkeys}
          has_blocked_contacts={@has_blocked_contacts}
          blocked_contacts_count={@blocked_contacts_count}
          waitlisted={@user.state == "waitlisted"}
          referral_code={@referral_code}
          referral_count={@referral_count}
          referral_threshold={@referral_threshold}
        />

        <div class="grid gap-3 grid-cols-1 sm:grid-cols-2 mt-3">
          <.hub_card
            navigate={~p"/my/settings"}
            icon="hero-cog-6-tooth"
            title={gettext("Settings")}
            subtitle={@profile_preview}
          />
          <.hub_card
            navigate={~p"/my/logs"}
            icon="hero-document-text"
            title={gettext("Logs")}
            subtitle={gettext("Your account activity logs")}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Conversation row component ---

  attr :conversation, :map, required: true
  attr :avatar_photos, :map, default: %{}
  attr :online_user_ids, :any, default: MapSet.new()
  attr :current_scope, :any, default: nil
  attr :unread, :boolean, default: false

  defp conversation_row(assigns) do
    ~H"""
    <div
      phx-click="open_chat"
      phx-value-user-id={@conversation.other_user.id}
      phx-value-conversation-id={@conversation.conversation.id}
      class={[
        "flex items-center gap-3 p-3 rounded-lg cursor-pointer transition-colors",
        "hover:bg-base-200",
        @unread && "bg-primary/5"
      ]}
    >
      <%!-- Avatar --%>
      <.user_avatar
        user={@conversation.other_user}
        photos={@avatar_photos}
        size={:sm}
        online={MapSet.member?(@online_user_ids, @conversation.other_user.id)}
        current_scope={@current_scope}
      />

      <%!-- Name + preview --%>
      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between">
          <span class={["text-sm truncate", @unread && "font-semibold"]}>
            {@conversation.other_user.display_name}
          </span>
          <span
            :if={@conversation.latest_message}
            class="text-xs text-base-content/40 flex-shrink-0 ml-2"
          >
            {format_conversation_time(@conversation.latest_message.inserted_at)}
          </span>
        </div>
        <p :if={@conversation.latest_message} class="text-xs text-base-content/50 truncate">
          {@conversation.latest_message.content}
        </p>
      </div>

      <%!-- Unread dot --%>
      <div :if={@unread} class="w-2.5 h-2.5 rounded-full bg-primary flex-shrink-0"></div>
    </div>
    """
  end

  # --- Mount ---

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    waitlist_assigns = WaitlistData.load_waitlist_assigns(user)
    profile_completeness = waitlist_assigns[:profile_completeness]

    mode =
      if profile_completeness.completed_count >= @dashboard_threshold and
           user.state != "waitlisted" do
        :dashboard
      else
        :hub
      end

    socket =
      assign(socket,
        user: user,
        mode: mode
      )

    socket =
      case mode do
        :dashboard -> mount_dashboard(socket, user, waitlist_assigns)
        :hub -> mount_hub(socket, user, waitlist_assigns, profile_completeness)
      end

    {:ok, socket}
  end

  defp mount_dashboard(socket, user, waitlist_assigns) do
    countdown_text = Spotlight.format_countdown(Spotlight.seconds_until_midnight())
    conversations = Messaging.list_conversations(user.id)
    unread_conversations = Enum.filter(conversations, & &1.unread)
    conversation_avatars = AvatarHelpers.load_from_conversations(conversations)

    if connected?(socket) do
      send(self(), :load_spotlight)
      schedule_countdown_tick()
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.user_topic(user.id))
    end

    socket
    |> assign(:page_title, gettext("My Hub"))
    |> assign(:loading_spotlight, true)
    |> assign(:candidates, [])
    |> assign(:wildcard_ids, MapSet.new())
    |> assign(:avatar_photos, %{})
    |> assign(:city_names, %{})
    |> assign(:first_stories, %{})
    |> assign(:visited_ids, MapSet.new())
    |> assign(:countdown_text, countdown_text)
    |> assign(:conversations, conversations)
    |> assign(:unread_conversations, unread_conversations)
    |> assign(:conversation_avatars, conversation_avatars)
    |> assign(:total_conversation_count, length(conversations))
    |> assign(:chat_open, false)
    |> assign(:chat_profile_user, nil)
    |> assign(:chat_conversation_id, nil)
    |> assign(:chat_subscribed, false)
    |> assign(:chat_typing_timer, nil)
    |> assign(waitlist_assigns)
  end

  defp mount_hub(socket, user, waitlist_assigns, profile_completeness) do
    profile_preview =
      if profile_completeness.completed_count < profile_completeness.total_count do
        gettext("%{completed}/%{total} complete",
          completed: profile_completeness.completed_count,
          total: profile_completeness.total_count
        )
      else
        gettext("Profile complete")
      end

    page_title =
      if user.state == "waitlisted" do
        days_remaining = waitlist_days_remaining(user.end_waitlist_at)

        if days_remaining && days_remaining > 0 do
          ngettext(
            "Waitlisted — %{count} day left",
            "Waitlisted — %{count} days left",
            days_remaining,
            count: days_remaining
          )
        else
          gettext("Waitlisted")
        end
      else
        gettext("My Hub")
      end

    socket
    |> assign(:page_title, page_title)
    |> assign(:profile_preview, profile_preview)
    |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
    |> assign(waitlist_assigns)
  end

  # --- Events ---

  @impl true
  def handle_event(
        "open_chat",
        %{"user-id" => other_user_id, "conversation-id" => conv_id},
        socket
      ) do
    other_user = Animina.Accounts.get_user(other_user_id)

    socket =
      socket
      |> assign(:chat_open, true)
      |> assign(:chat_profile_user, other_user)
      |> assign(:chat_conversation_id, conv_id)

    socket =
      if socket.assigns.chat_subscribed do
        socket
      else
        subscribe_to_chat(socket, conv_id)
      end

    {:noreply, socket}
  end

  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    {columns, updated_user} =
      ColumnPreferences.persist_columns(
        socket.assigns.current_scope.user,
        columns_str
      )

    {:noreply,
     socket
     |> assign(:columns, columns)
     |> ColumnPreferences.update_scope_user(updated_user)}
  end

  # --- Info handlers (dashboard mode) ---

  @impl true
  def handle_info(:load_spotlight, socket) do
    viewer = socket.assigns.user

    {candidates, wildcard_ids} = Spotlight.get_or_seed_daily(viewer)

    candidate_ids = Enum.map(candidates, & &1.id)

    avatar_photos = AvatarHelpers.load_from_users(candidates)
    city_names = load_city_names(candidates)
    first_stories = Moodboard.first_story_content_per_users(candidate_ids)
    visited_ids = Discovery.visited_profile_ids(viewer.id, candidate_ids)

    {:noreply,
     socket
     |> assign(:loading_spotlight, false)
     |> assign(:candidates, candidates)
     |> assign(:wildcard_ids, wildcard_ids)
     |> assign(:avatar_photos, avatar_photos)
     |> assign(:city_names, city_names)
     |> assign(:first_stories, first_stories)
     |> assign(:visited_ids, visited_ids)}
  end

  @impl true
  def handle_info(:countdown_tick, socket) do
    seconds = Spotlight.seconds_until_midnight()

    socket =
      if seconds <= 0 do
        send(self(), :load_spotlight)
        assign(socket, :countdown_text, Spotlight.format_countdown(0))
      else
        assign(socket, :countdown_text, Spotlight.format_countdown(seconds))
      end

    schedule_countdown_tick()
    {:noreply, socket}
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

  # User-level PubSub (3-tuple) — refresh conversations list
  @impl true
  def handle_info({:new_message, _conversation_id, _message}, socket) do
    {:noreply, refresh_conversations(socket)}
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
    if user_id != socket.assigns.user.id do
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
  def handle_info({:unread_count_changed, _count}, socket) do
    {:noreply, refresh_conversations(socket)}
  end

  @impl true
  def handle_info({event, _conversation_id}, socket)
      when event in [:conversation_closed, :conversation_reopened] do
    {:noreply, refresh_conversations(socket)}
  end

  # Catch-all for other PubSub messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # --- Private helpers ---

  defp schedule_countdown_tick do
    Process.send_after(self(), :countdown_tick, @countdown_interval)
  end

  defp refresh_conversations(socket) do
    user_id = socket.assigns.user.id
    conversations = Messaging.list_conversations(user_id)
    unread_conversations = Enum.filter(conversations, & &1.unread)
    avatars = AvatarHelpers.load_from_conversations(conversations)

    assign(socket,
      conversations: conversations,
      unread_conversations: unread_conversations,
      conversation_avatars: avatars,
      total_conversation_count: length(conversations)
    )
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

  defp load_city_names(users) do
    users
    |> Enum.flat_map(fn user ->
      case user.locations do
        locations when is_list(locations) -> locations
        _ -> []
      end
    end)
    |> GeoData.city_names_for_locations()
  end

  defp format_conversation_time(datetime) do
    now = DateTime.utc_now()
    diff_days = Date.diff(DateTime.to_date(now), DateTime.to_date(datetime))

    cond do
      diff_days == 0 -> Calendar.strftime(datetime, "%H:%M")
      diff_days == 1 -> gettext("Yesterday")
      diff_days < 7 -> Calendar.strftime(datetime, "%A")
      true -> Calendar.strftime(datetime, "%d.%m.%Y")
    end
  end

  defp waitlist_days_remaining(nil), do: nil

  defp waitlist_days_remaining(end_at) do
    diff = DateTime.diff(end_at, DateTime.utc_now(), :second)
    if diff > 0, do: div(diff, 86_400), else: 0
  end
end
