defmodule AniminaWeb.MessagesLive do
  @moduledoc """
  LiveView for the messaging system.

  Supports two views:
  - Index: List of all conversations
  - Show: Individual conversation with messages

  Features:
  - Real-time message updates via PubSub
  - Typing indicators with auto-timeout
  - Read receipts
  - Date separators and message grouping
  - Enter-to-send with auto-growing textarea
  - Smart scroll (doesn't yank to bottom when reading history)
  - Message deletion for own unread messages
  """

  use AniminaWeb, :live_view

  import AniminaWeb.MessageComponents
  import AniminaWeb.RelationshipComponents

  alias Animina.FeatureFlags
  alias Animina.Messaging
  alias Animina.Photos
  alias Animina.Relationships
  alias AniminaWeb.Helpers.AvatarHelpers

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto flex flex-col h-[calc(100vh-12rem)]">
        <h1 class="sr-only">{gettext("Conversation")}</h1>
        <.breadcrumb_nav class="mb-2">
          <:crumb navigate={~p"/my"}>{gettext("My Hub")}</:crumb>
          <:crumb navigate={~p"/my/messages"}>{gettext("Messages")}</:crumb>
        </.breadcrumb_nav>
        <%!-- Conversation Header --%>
        <div class="flex items-center gap-3 pb-4 border-b border-base-300">
          <.link navigate={~p"/my/messages"} class="btn btn-ghost btn-sm btn-circle" aria-label={gettext("Back to messages")}>
            <.icon name="hero-arrow-left" class="h-5 w-5" />
          </.link>

          <%= if @conversation_data do %>
            <.link
              navigate={~p"/users/#{@conversation_data.other_user.id}"}
              class="flex items-center gap-3 hover:opacity-80 transition-opacity"
            >
              <.user_avatar
                user={@conversation_data.other_user}
                photos={@avatar_photos}
                size={:sm}
                online={MapSet.member?(@online_user_ids, @conversation_data.other_user.id)}
                current_scope={@current_scope}
              />
              <div>
                <div class="font-semibold flex items-center gap-2">
                  {@conversation_data.other_user.display_name}
                  <span
                    :if={@relationship}
                    class={["badge badge-sm", relationship_badge_class(@relationship.status)]}
                  >
                    {relationship_status_label(@relationship.status)}
                  </span>
                </div>
                <div :if={@typing} class="text-xs text-primary animate-pulse">
                  {gettext("typing...")}
                </div>
              </div>
            </.link>

            <div class="flex-1" />

            <%!-- Kebab menu --%>
            <div class="relative">
              <button
                phx-click={JS.toggle(to: "#relationship-menu", in: "fade-in", out: "fade-out")}
                class="btn btn-ghost btn-sm btn-circle"
                title={gettext("Actions")}
              >
                <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
              </button>
              <div
                id="relationship-menu"
                class="hidden absolute right-0 top-full mt-1 w-56 bg-base-100 rounded-lg shadow-xl border border-base-300 z-50 py-1"
                phx-click-away={JS.hide(to: "#relationship-menu")}
              >
                <%= for {action, label, icon, style} <- available_actions(@relationship, @current_scope.user.id) do %>
                  <%= if action == :divider do %>
                    <div class="border-t border-base-300 my-1" />
                  <% else %>
                    <button
                      phx-click="relationship_action"
                      phx-value-action={action}
                      class={[
                        "flex items-center gap-2 w-full px-4 py-2 text-sm hover:bg-base-200 transition-colors",
                        action_text_class(style)
                      ]}
                    >
                      <.icon name={icon} class="h-4 w-4" />
                      {label}
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Proposal Banner --%>
        <.proposal_banner
          :if={@relationship && @relationship.pending_status}
          relationship={@relationship}
          current_user_id={@current_scope.user.id}
          other_user_name={@conversation_data && @conversation_data.other_user.display_name}
        />

        <%!-- Timeline Panel --%>
        <div
          :if={@show_timeline && @relationship}
          class="bg-base-100 rounded-lg border border-base-300 p-4 mb-2 max-h-48 overflow-y-auto"
        >
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-sm font-semibold text-base-content/70">
              {gettext("Relationship Timeline")}
            </h3>
            <button phx-click="close_timeline" class="btn btn-ghost btn-xs btn-circle">
              <.icon name="hero-x-mark" class="h-3.5 w-3.5" />
            </button>
          </div>
          <.relationship_timeline
            milestones={@milestones}
            users={timeline_users(assigns)}
            current_user_id={@current_scope.user.id}
          />
        </div>

        <%!-- Messages --%>
        <div
          id="messages-container"
          class="flex-1 overflow-y-auto py-4"
          phx-hook="ScrollToBottom"
        >
          <%= if Enum.empty?(@messages) do %>
            <div class="text-center py-12 text-base-content/50">
              <.icon name="hero-chat-bubble-left-right" class="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>{gettext("No messages yet")}</p>
              <p class="text-sm mt-2">{gettext("Send a message to start the conversation")}</p>
            </div>
          <% else %>
            <.message_group
              :for={group <- @grouped_messages}
              group={group}
              current_user_id={@current_scope.user.id}
              other_user={@conversation_data && @conversation_data.other_user}
              other_last_read_at={@other_last_read_at}
              last_read_message_id={@last_read_message_id}
              other_user_online={@conversation_data != nil && MapSet.member?(@online_user_ids, @conversation_data.other_user.id)}
            />
          <% end %>
        </div>

        <%!-- Message Input --%>
        <.chat_input
          form={@form}
          input_id="message-input"
          form_id="message-form"
          draft_key={"draft:#{@current_scope.user.id}:#{@conversation_data && @conversation_data.other_user.id}"}
          blocked={@conversation_data != nil && @conversation_data.blocked}
        />
      </div>

      <%!-- Report Modal --%>
      <.live_component
        :if={@show_report_modal && @conversation_data}
        module={AniminaWeb.ReportModalComponent}
        id="report-modal"
        show={@show_report_modal}
        reported_user={@conversation_data.other_user}
        context_type="chat"
        context_id={@conversation_data.conversation.id}
        current_scope={@current_scope}
      />

      <%!-- Confirmation Dialog --%>
      <div
        :if={@confirm_action}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
        phx-click="cancel_confirm"
      >
        <div
          class="bg-base-100 rounded-lg p-6 max-w-sm mx-4 shadow-xl"
          phx-click-away="cancel_confirm"
        >
          <h3 class="text-lg font-semibold">{elem(@confirm_action, 0)}</h3>
          <p class="text-base-content/70 mt-2 text-sm">{elem(@confirm_action, 1)}</p>
          <div class="mt-6 flex gap-3 justify-end">
            <button phx-click="cancel_confirm" class="btn btn-ghost btn-sm">
              {gettext("Cancel")}
            </button>
            <button phx-click="execute_relationship_action" class="btn btn-error btn-sm">
              {elem(@confirm_action, 2)}
            </button>
          </div>
        </div>
      </div>

      <%!-- Override Settings Modal --%>
      <div
        :if={@show_override_modal && @relationship}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
        phx-click="close_override_modal"
      >
        <div
          class="bg-base-100 rounded-lg p-6 max-w-md mx-4 shadow-xl"
          phx-click-away="close_override_modal"
        >
          <h3 class="text-lg font-semibold mb-4">
            {gettext("Custom Permissions for %{name}",
              name: @conversation_data && @conversation_data.other_user.display_name
            )}
          </h3>
          <form phx-submit="save_overrides">
            <div class="space-y-4">
              <.override_toggle
                field="can_see_profile"
                label={gettext("Can see my profile")}
                checked={override_value(@override, :can_see_profile, @relationship.status)}
                default={status_default(@relationship.status, :can_see_profile)}
              />
              <.override_toggle
                field="can_message_me"
                label={gettext("Can message me")}
                checked={override_value(@override, :can_message_me, @relationship.status)}
                default={status_default(@relationship.status, :can_message)}
              />
              <.override_toggle
                field="visible_in_discovery"
                label={gettext("Show in my discovery")}
                checked={override_value(@override, :visible_in_discovery, @relationship.status)}
                default={status_default(@relationship.status, :visible_in_discovery)}
              />
            </div>
            <div class="mt-6 flex gap-3 justify-end">
              <button type="button" phx-click="close_override_modal" class="btn btn-ghost btn-sm">
                {gettext("Cancel")}
              </button>
              <button type="submit" class="btn btn-primary btn-sm">
                {gettext("Save")}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.breadcrumb_nav>
          <:crumb navigate={~p"/my"}>{gettext("My Hub")}</:crumb>
          <:crumb>{gettext("Messages")}</:crumb>
        </.breadcrumb_nav>
        <.header>
          {gettext("Messages")}
        </.header>

        <div class="mt-6">
          <%= if Enum.empty?(@conversations) do %>
            <div class="text-center py-12 text-base-content/50">
              <.icon name="hero-chat-bubble-left-right" class="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p class="text-lg">{gettext("No conversations yet")}</p>
              <p class="text-sm mt-2">
                {gettext("Start a conversation from a user's profile")}
              </p>
            </div>
          <% else %>
            <div class="divide-y divide-base-300">
              <.conversation_row
                :for={conv <- @conversations}
                conversation={conv}
                avatar_photos={@avatar_photos}
                relationship_status={Map.get(@relationship_map, conv.other_user.id)}
                online_user_ids={@online_user_ids}
                current_scope={@current_scope}
              />
            </div>
          <% end %>
        </div>

        <%!-- Let Go Archive Section --%>
        <div :if={@closed_conversations != []} class="mt-10">
          <div class="divider"></div>
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-archive-box" class="h-5 w-5 text-base-content/50" />
            <h2 class="text-lg font-semibold text-base-content/70">
              {gettext("Let Go Archive")}
            </h2>
          </div>
          <p class="text-sm text-base-content/50 mb-4">
            {gettext("Conversations you've let go of. You can reopen one via Love Emergency.")}
          </p>
          <div class="space-y-3">
            <.closed_conversation_card
              :for={closure <- @closed_conversations}
              closure={closure}
              avatar_photos={@closed_avatar_photos}
              love_emergency_cost={@love_emergency_cost}
            />
          </div>
        </div>

        <%!-- Love Emergency Component --%>
        <.live_component
          :if={@show_love_emergency}
          module={AniminaWeb.LoveEmergencyComponent}
          id="love-emergency"
          conversation_id_to_reopen={@love_emergency_conv_id}
          current_user_id={@current_scope.user.id}
          active_conversations={@love_emergency_active_conversations}
          cost={@love_emergency_cost}
        />

        <%!-- Let Go Confirmation --%>
        <div
          :if={@confirm_let_go_conv_id}
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
          phx-click="cancel_let_go"
        >
          <div
            class="bg-base-100 rounded-lg p-6 max-w-sm mx-4 shadow-xl"
            phx-click-away="cancel_let_go"
          >
            <h3 class="text-lg font-semibold">
              {gettext("Let go of this conversation?")}
            </h3>
            <p class="text-base-content/70 mt-2 text-sm">
              {gettext("This is permanent. Both of you will no longer see each other in discovery.")}
            </p>
            <div class="mt-6 flex gap-3 justify-end">
              <button phx-click="cancel_let_go" class="btn btn-ghost btn-sm">
                {gettext("Cancel")}
              </button>
              <button phx-click="confirm_let_go" class="btn btn-error btn-sm">
                <.icon name="hero-hand-raised" class="h-4 w-4" />
                {gettext("Let Go")}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Conversation row component ---

  attr :conversation, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :relationship_status, :string, default: nil
  attr :online_user_ids, :any, default: MapSet.new()
  attr :current_scope, :any, default: nil

  defp conversation_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-3 p-4 -mx-4",
      @conversation.unread && "bg-primary/5"
    ]}>
      <.link
        navigate={~p"/my/messages/#{@conversation.conversation.id}"}
        class="flex items-center gap-3 flex-1 min-w-0 hover:opacity-80 transition-opacity"
      >
        <.user_avatar
          user={@conversation.other_user}
          photos={@avatar_photos}
          size={:md}
          online={MapSet.member?(@online_user_ids, @conversation.other_user.id)}
          current_scope={@current_scope}
        />

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <span class={["font-medium truncate", @conversation.unread && "font-semibold"]}>
              {@conversation.other_user.display_name}
            </span>
            <span
              :if={@relationship_status && @relationship_status != "chatting"}
              class={["badge badge-xs", relationship_badge_class(@relationship_status)]}
            >
              {relationship_status_label(@relationship_status)}
            </span>
            <%= if @conversation.unread do %>
              <span class="w-2 h-2 rounded-full bg-primary flex-shrink-0" />
            <% end %>
          </div>
          <%= if @conversation.draft_content do %>
            <p class="text-sm truncate mt-0.5 text-error">
              <span class="font-medium">{gettext("Draft:")}</span>
              {strip_markdown(@conversation.draft_content)}
            </p>
          <% else %>
            <%= if @conversation.latest_message do %>
              <p class={[
                "text-sm truncate mt-0.5",
                if(@conversation.unread, do: "text-base-content", else: "text-base-content/60")
              ]}>
                {strip_markdown(@conversation.latest_message.content)}
              </p>
            <% end %>
          <% end %>
        </div>

        <%= if @conversation.latest_message do %>
          <span class="text-xs text-base-content/40 flex-shrink-0">
            {format_time(@conversation.latest_message.inserted_at)}
          </span>
        <% end %>
      </.link>

      <button
        phx-click="let_go"
        phx-value-conversation-id={@conversation.conversation.id}
        class="btn btn-ghost btn-xs text-base-content/30 hover:text-warning flex-shrink-0"
        title={gettext("Let go")}
      >
        <.icon name="hero-hand-raised" class="h-3.5 w-3.5" />
      </button>
    </div>
    """
  end

  # --- Closed conversation card component ---

  attr :closure, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :love_emergency_cost, :integer, required: true

  defp closed_conversation_card(assigns) do
    other_user = assigns.closure.other_user

    assigns =
      assigns
      |> assign(:other_user, other_user)
      |> assign(:age, if(other_user, do: Animina.Accounts.compute_age(other_user.birthday)))

    ~H"""
    <div
      :if={@other_user}
      class="flex items-center gap-3 p-3 rounded-lg border border-base-300/50 bg-base-100/50"
    >
      <.user_avatar user={@other_user} photos={@avatar_photos} size={:md} />
      <div class="flex-1 min-w-0">
        <div class="font-medium truncate">{@other_user.display_name}</div>
        <div class="text-xs text-base-content/50">
          <span :if={@age}>{gettext("%{age} years", age: @age)}</span>
          <span :if={@other_user.height} class="mx-1">&bull;</span>
          <span :if={@other_user.height}>{@other_user.height} cm</span>
        </div>
      </div>
      <button
        phx-click="love_emergency"
        phx-value-conversation-id={@closure.conversation_id}
        class="btn btn-sm btn-outline btn-error"
        title={gettext("Reopen by closing %{cost} other conversations", cost: @love_emergency_cost)}
      >
        <.icon name="hero-heart" class="h-4 w-4" />
        {gettext("Reopen")}
      </button>
    </div>
    """
  end

  # --- Message group component (date separator + grouped bubbles) ---

  attr :group, :map, required: true
  attr :current_user_id, :string, required: true
  attr :other_user, :map, default: nil
  attr :other_last_read_at, :any, default: nil
  attr :last_read_message_id, :string, default: nil
  attr :other_user_online, :boolean, default: false

  defp message_group(assigns) do
    ~H"""
    <%!-- Date separator --%>
    <div class="flex items-center gap-3 my-4">
      <div class="flex-1 border-t border-base-300" />
      <span class="text-xs text-base-content/60 font-medium">{@group.date_label}</span>
      <div class="flex-1 border-t border-base-300" />
    </div>

    <%!-- Message clusters --%>
    <div :for={cluster <- @group.clusters}>
      <.message_bubble
        :for={{message, meta} <- cluster.messages}
        message={message}
        is_sender={message.sender_id == @current_user_id}
        is_first={meta.first}
        is_last={meta.last}
        show_time={meta.show_time}
        is_read={read_message?(message, @current_user_id, @other_last_read_at)}
        read_at={if(message.id == @last_read_message_id, do: @other_last_read_at)}
        other_user={@other_user}
        current_user_id={@current_user_id}
        other_user_online={@other_user_online}
      />
    </div>
    """
  end

  # --- Message bubble component ---

  attr :message, :map, required: true
  attr :is_sender, :boolean, required: true
  attr :is_first, :boolean, default: true
  attr :is_last, :boolean, default: true
  attr :show_time, :boolean, default: true
  attr :is_read, :boolean, default: false
  attr :read_at, :any, default: nil
  attr :other_user, :map, default: nil
  attr :current_user_id, :string, default: nil
  attr :other_user_online, :boolean, default: false

  defp message_bubble(assigns) do
    assigns = assign(assigns, :deletable, message_deletable?(assigns))

    ~H"""
    <div class={[
      "flex group",
      @is_sender && "justify-end",
      if(@is_first, do: "mt-2", else: "mt-0.5")
    ]}>
      <div class="relative max-w-[80%]">
        <div class={bubble_classes(@is_sender, @is_first, @is_last)}>
          <div class={[
            "prose prose-sm max-w-none break-words [&>p]:my-0.5 [&_blockquote]:!text-inherit [&_blockquote_p]:before:content-none [&_blockquote_p]:after:content-none",
            if(@is_sender, do: "prose-invert !text-primary-content", else: "!text-base-content")
          ]}>
            {render_markdown(@message.content)}
          </div>
          <div
            :if={@show_time}
            class={[
              "text-xs mt-1 flex items-center gap-1",
              if(@is_sender, do: "text-primary-content justify-end", else: "text-base-content/70")
            ]}
          >
            {format_message_time(@message.inserted_at)}
            <%= if @message.edited_at do %>
              <span>· {gettext("edited")}</span>
            <% end %>
            <%= if @is_sender do %>
              <%= if @is_read do %>
                <span class="read-receipt ml-0.5" title={format_read_time(@read_at)}>
                  <.icon name="hero-check" class="h-3 w-3 inline" /><.icon
                    name="hero-check"
                    class="h-3 w-3 inline -ml-1.5"
                  />
                </span>
                <%= if @read_at do %>
                  <span class="read-time ml-0.5">· {format_read_time(@read_at)}</span>
                <% end %>
              <% else %>
                <span class="sent-receipt ml-0.5" title={gettext("Sent")}>
                  <.icon name="hero-check" class="h-3 w-3 inline opacity-60" />
                </span>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Delete button: only within 15min window, other user offline, and unread --%>
        <button
          :if={@deletable}
          id={"delete-message-#{@message.id}"}
          phx-click="delete_message"
          phx-value-id={@message.id}
          data-confirm={gettext("Delete this message?")}
          class="absolute -left-8 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-opacity btn btn-ghost btn-xs btn-circle"
          title={gettext("Delete")}
        >
          <.icon name="hero-trash" class="h-3.5 w-3.5 text-error" />
        </button>
      </div>
    </div>
    """
  end

  defp message_deletable?(assigns) do
    assigns.is_sender &&
      !assigns.is_read &&
      !assigns.other_user_online &&
      within_delete_window?(assigns.message)
  end

  defp within_delete_window?(message) do
    age_seconds = DateTime.diff(DateTime.utc_now(), message.inserted_at, :second)
    age_seconds <= Messaging.delete_window_seconds()
  end

  defp bubble_classes(true = _sender, first, last),
    do: ["px-4 py-2", "bg-primary text-primary-content", bubble_radius("r", "b", first, last)]

  defp bubble_classes(false = _sender, first, last),
    do: ["px-4 py-2", "bg-base-200 text-base-content", bubble_radius("l", "b", first, last)]

  defp bubble_radius(side, corner, true, true), do: "rounded-2xl rounded-#{corner}#{side}-md"
  defp bubble_radius(side, corner, true, false), do: "rounded-2xl rounded-#{corner}#{side}-sm"

  defp bubble_radius(side, corner, false, true),
    do: "rounded-2xl rounded-t#{side}-sm rounded-#{corner}#{side}-md"

  defp bubble_radius(side, _corner, false, false), do: "rounded-2xl rounded-#{side}-sm"

  # --- Proposal banner component ---

  attr :relationship, :map, required: true
  attr :current_user_id, :string, required: true
  attr :other_user_name, :string, default: nil

  defp proposal_banner(assigns) do
    ~H"""
    <%= if @relationship.pending_proposed_by == @current_user_id do %>
      <div class="mx-0 mb-2 p-3 bg-primary/10 rounded-lg text-sm flex items-center justify-between">
        <span>
          {gettext("You proposed %{status}. Waiting for response.",
            status: relationship_status_label(@relationship.pending_status)
          )}
        </span>
        <button phx-click="cancel_proposal" class="btn btn-ghost btn-xs">
          {gettext("Cancel")}
        </button>
      </div>
    <% else %>
      <div class="mx-0 mb-2 p-3 bg-primary/10 rounded-lg text-sm flex items-center justify-between">
        <span>
          {gettext("%{name} proposed %{status}!",
            name: @other_user_name,
            status: relationship_status_label(@relationship.pending_status)
          )}
        </span>
        <div class="flex gap-2">
          <button phx-click="accept_proposal" class="btn btn-primary btn-xs">
            {gettext("Accept")}
          </button>
          <button phx-click="decline_proposal" class="btn btn-ghost btn-xs">
            {gettext("Decline")}
          </button>
        </div>
      </div>
    <% end %>
    """
  end

  # --- Override toggle component ---

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :checked, :boolean, required: true
  attr :default, :boolean, required: true

  defp override_toggle(assigns) do
    ~H"""
    <label class="flex items-center justify-between cursor-pointer">
      <div>
        <span class="text-sm font-medium">{@label}</span>
        <span class="text-xs text-base-content/50 block">
          {if @default, do: gettext("Default: allowed"), else: gettext("Default: not allowed")}
        </span>
      </div>
      <input
        type="checkbox"
        name={@field}
        value="true"
        checked={@checked}
        class="toggle toggle-primary"
      />
    </label>
    """
  end

  defp action_text_class(:danger), do: "text-error"
  defp action_text_class(:warning), do: "text-warning"
  defp action_text_class(_), do: "text-base-content/70"

  defp available_actions(nil, _user_id), do: []

  defp available_actions(relationship, user_id) do
    status = relationship.status
    has_pending = relationship.pending_status != nil
    is_proposer = relationship.pending_proposed_by == user_id

    # Upgrade action (or cancel if already proposed)
    upgrade_actions =
      cond do
        has_pending && is_proposer ->
          [{:cancel_proposal, gettext("Cancel Proposal"), "hero-x-mark", :normal}]

        has_pending ->
          []

        true ->
          case upgrade_action_for_status(status) do
            nil -> []
            {action, label, icon} -> [{action, label, icon, :normal}]
          end
      end

    # Override settings (for active statuses)
    override_action =
      if status in ~w(chatting dating couple married friend separated) do
        [
          {:open_override_modal, gettext("Override Settings"), "hero-adjustments-horizontal",
           :normal}
        ]
      else
        []
      end

    # Destructive/other actions
    other_actions = destructive_actions_for_status(status)

    # Report (always available unless blocked)
    report_action =
      if status != "blocked" do
        [{:open_report_modal, gettext("Report"), "hero-flag", :danger}]
      else
        []
      end

    # Timeline action (available when relationship exists)
    timeline_action =
      [{:toggle_timeline, gettext("Timeline"), "hero-clock", :normal}]

    # Combine with dividers
    sections =
      [upgrade_actions, timeline_action, override_action, other_actions, report_action]
      |> Enum.reject(&(&1 == []))
      |> Enum.intersperse([{:divider, "", "", :normal}])
      |> List.flatten()

    sections
  end

  defp upgrade_action_for_status("chatting"),
    do: {:propose_dating, gettext("Propose Dating"), "hero-heart"}

  defp upgrade_action_for_status("dating"),
    do: {:propose_couple, gettext("Propose Couple"), "hero-users"}

  defp upgrade_action_for_status("couple"),
    do: {:propose_marriage, gettext("Propose Marriage"), "hero-sparkles"}

  defp upgrade_action_for_status("separated"),
    do: {:propose_friend, gettext("Propose Friend"), "hero-hand-raised"}

  defp upgrade_action_for_status("divorced"),
    do: {:propose_friend, gettext("Propose Friend"), "hero-hand-raised"}

  defp upgrade_action_for_status("ex"),
    do: {:propose_friend, gettext("Propose Friend"), "hero-hand-raised"}

  defp upgrade_action_for_status("ended"),
    do: {:propose_friend, gettext("Propose Friend"), "hero-hand-raised"}

  defp upgrade_action_for_status(_), do: nil

  defp destructive_actions_for_status("chatting") do
    [
      {:end_conversation, gettext("End Conversation"), "hero-x-circle", :warning},
      {:block, gettext("Block"), "hero-no-symbol", :danger}
    ]
  end

  defp destructive_actions_for_status("dating") do
    [
      {:end_relationship, gettext("End Relationship"), "hero-x-circle", :warning},
      {:block, gettext("Block"), "hero-no-symbol", :danger}
    ]
  end

  defp destructive_actions_for_status("couple") do
    [
      {:separate, gettext("Separate"), "hero-arrows-pointing-out", :warning},
      {:block, gettext("Block"), "hero-no-symbol", :danger}
    ]
  end

  defp destructive_actions_for_status("married") do
    [
      {:separate, gettext("Separate"), "hero-arrows-pointing-out", :warning},
      {:block, gettext("Block"), "hero-no-symbol", :danger}
    ]
  end

  defp destructive_actions_for_status("separated") do
    [
      {:divorce, gettext("Divorce"), "hero-document-text", :warning},
      {:block, gettext("Block"), "hero-no-symbol", :danger}
    ]
  end

  defp destructive_actions_for_status("divorced") do
    [{:block, gettext("Block"), "hero-no-symbol", :danger}]
  end

  defp destructive_actions_for_status("ex") do
    [{:block, gettext("Block"), "hero-no-symbol", :danger}]
  end

  defp destructive_actions_for_status("friend") do
    [
      {:end_friendship, gettext("End Friendship"), "hero-x-circle", :warning},
      {:block, gettext("Block"), "hero-no-symbol", :danger}
    ]
  end

  defp destructive_actions_for_status("blocked") do
    [{:unblock, gettext("Unblock"), "hero-lock-open", :normal}]
  end

  defp destructive_actions_for_status("ended"), do: []
  defp destructive_actions_for_status(_), do: []

  defp override_value(nil, field, status) do
    defaults = Relationships.status_defaults()
    defaults_for_status = Map.get(defaults, status, %{})
    # Map field names: :can_message_me in override -> :can_message in defaults
    default_key = if field == :can_message_me, do: :can_message, else: field
    Map.get(defaults_for_status, default_key, true)
  end

  defp override_value(override, field, status) do
    case Map.get(override, field) do
      nil -> override_value(nil, field, status)
      value -> value
    end
  end

  defp status_default(status, field) do
    defaults = Relationships.status_defaults()
    defaults_for_status = Map.get(defaults, status, %{})
    Map.get(defaults_for_status, field, true)
  end

  # --- Time formatting helpers ---

  defp format_time(datetime) do
    now = DateTime.utc_now()
    diff_days = Date.diff(DateTime.to_date(now), DateTime.to_date(datetime))

    cond do
      diff_days == 0 ->
        Calendar.strftime(datetime, "%H:%M")

      diff_days == 1 ->
        gettext("Yesterday")

      diff_days < 7 ->
        Calendar.strftime(datetime, "%A")

      true ->
        Calendar.strftime(datetime, "%d.%m.%Y")
    end
  end

  defp format_message_time(datetime), do: format_relative_time(datetime)

  defp format_date_label(date) do
    today = Date.utc_today()
    diff = Date.diff(today, date)

    cond do
      diff == 0 -> gettext("Today")
      diff == 1 -> gettext("Yesterday")
      diff < 7 -> Calendar.strftime(date, "%A")
      true -> Calendar.strftime(date, "%d.%m.%Y")
    end
  end

  # --- Message grouping logic ---

  defp group_messages(messages) do
    messages
    |> Enum.group_by(fn msg -> DateTime.to_date(msg.inserted_at) end)
    |> Enum.sort_by(fn {date, _} -> date end, Date)
    |> Enum.map(fn {date, day_messages} ->
      %{
        date_label: format_date_label(date),
        clusters: build_clusters(day_messages)
      }
    end)
  end

  # Group consecutive messages from the same sender within 2 minutes
  defp build_clusters(messages) do
    messages
    |> Enum.chunk_while(
      [],
      fn msg, acc ->
        if should_cluster?(acc, msg) do
          {:cont, acc ++ [msg]}
        else
          {:cont, build_cluster(acc), [msg]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, build_cluster(acc), []}
      end
    )
  end

  defp should_cluster?([], _msg), do: true

  defp should_cluster?(acc, msg) do
    prev = List.last(acc)

    msg.sender_id == prev.sender_id &&
      DateTime.diff(msg.inserted_at, prev.inserted_at, :second) <= 120
  end

  defp build_cluster(messages) do
    count = length(messages)

    annotated =
      messages
      |> Enum.with_index()
      |> Enum.map(fn {msg, idx} ->
        {msg,
         %{
           first: idx == 0,
           last: idx == count - 1,
           show_time: idx == count - 1
         }}
      end)

    %{messages: annotated}
  end

  # --- Read receipt helpers ---

  defp read_message?(message, current_user_id, other_last_read_at) do
    message.sender_id == current_user_id &&
      other_last_read_at != nil &&
      DateTime.compare(message.inserted_at, other_last_read_at) != :gt
  end

  defp find_last_read_message_id(messages, current_user_id, other_last_read_at) do
    messages
    |> Enum.filter(&read_message?(&1, current_user_id, other_last_read_at))
    |> List.last()
    |> then(fn
      nil -> nil
      msg -> msg.id
    end)
  end

  defp format_read_time(nil), do: gettext("Read")

  defp format_read_time(datetime),
    do: gettext("Read %{time}", time: format_relative_time(datetime))

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)
    diff_days = Date.diff(DateTime.to_date(now), DateTime.to_date(datetime))

    cond do
      diff_seconds < 60 -> gettext("just now")
      diff_days == 0 -> Calendar.strftime(datetime, "%H:%M")
      diff_days == 1 -> gettext("Yesterday") <> " " <> Calendar.strftime(datetime, "%H:%M")
      diff_days < 7 -> Calendar.strftime(datetime, "%A %H:%M")
      true -> Calendar.strftime(datetime, "%d.%m.%Y %H:%M")
    end
  end

  # --- Mount and lifecycle ---

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Subscribe to user topic for real-time conversation updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.user_topic(user.id))
    end

    socket =
      assign(socket,
        page_title: gettext("Messages"),
        conversations: [],
        conversation_data: nil,
        messages: [],
        grouped_messages: [],
        avatar_photos: %{},
        typing: false,
        typing_timer: nil,
        draft_save_timer: nil,
        other_last_read_at: nil,
        last_read_message_id: nil,
        form: to_form(%{"content" => ""}, as: :message),
        slot_status: Messaging.chat_slot_status(user.id),
        closed_conversations: [],
        closed_avatar_photos: %{},
        love_emergency_cost: FeatureFlags.chat_love_emergency_cost(),
        confirm_let_go_conv_id: nil,
        show_love_emergency: false,
        love_emergency_conv_id: nil,
        love_emergency_active_conversations: [],
        love_emergency_selected: MapSet.new(),
        show_report_modal: false,
        relationship: nil,
        relationship_map: %{},
        show_override_modal: false,
        override: nil,
        confirm_action: nil,
        show_timeline: false,
        milestones: []
      )

    # Handle start_with param to create/open a conversation
    socket =
      case Map.get(params, "start_with") do
        nil -> socket
        target_id -> handle_start_with(socket, target_id)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    user = socket.assigns.current_scope.user
    conversations = Messaging.list_conversations(user.id)
    closed = Messaging.list_closed_conversations(user.id)

    # Load avatar photos for closed conversation users
    closed_users = closed |> Enum.map(& &1.other_user) |> Enum.reject(&is_nil/1)
    closed_avatar_photos = AvatarHelpers.load_from_users(closed_users)

    # Batch-load relationship statuses for conversation partners
    other_user_ids = Enum.map(conversations, & &1.other_user.id)

    relationship_map =
      user.id
      |> Relationships.get_relationships_for_user(other_user_ids)
      |> Map.new(fn rel -> {Relationships.other_user_id(rel, user.id), rel.status} end)

    assign(socket,
      page_title: gettext("Messages"),
      conversations: conversations,
      conversation_data: nil,
      messages: [],
      grouped_messages: [],
      avatar_photos: AvatarHelpers.load_from_conversations(conversations),
      other_last_read_at: nil,
      last_read_message_id: nil,
      slot_status: Messaging.chat_slot_status(user.id),
      closed_conversations: closed,
      closed_avatar_photos: closed_avatar_photos,
      relationship_map: relationship_map
    )
  end

  defp apply_action(socket, :show, %{"conversation_id" => conversation_id}) do
    user = socket.assigns.current_scope.user

    case Messaging.get_conversation_for_user(conversation_id, user.id) do
      nil ->
        socket
        |> put_flash(:error, gettext("Conversation not found"))
        |> redirect(to: ~p"/my/messages")

      conversation_data ->
        setup_conversation_view(socket, conversation_data, conversation_id, user)
    end
  end

  defp setup_conversation_view(socket, conversation_data, conversation_id, user) do
    subscribe_to_conversation(socket, conversation_id)
    Messaging.mark_as_read(conversation_id, user.id)

    messages = Messaging.list_messages(conversation_id, user.id)
    other_last_read_at = Messaging.get_other_participant_last_read(conversation_id, user.id)
    last_read_message_id = find_last_read_message_id(messages, user.id, other_last_read_at)

    other_user = conversation_data.other_user
    {relationship, override} = load_relationship_data(socket, user.id, other_user.id)

    {draft_content, draft_updated_at} = Messaging.get_draft(conversation_id, user.id)
    form_content = draft_content || ""

    socket =
      assign(socket,
        page_title: other_user.display_name,
        conversation_data: conversation_data,
        messages: messages,
        grouped_messages: group_messages(messages),
        avatar_photos: %{other_user.id => Photos.get_user_avatar(other_user.id)},
        other_last_read_at: other_last_read_at,
        last_read_message_id: last_read_message_id,
        form: to_form(%{"content" => form_content}, as: :message),
        relationship: relationship,
        override: override,
        show_override_modal: false,
        confirm_action: nil
      )

    maybe_push_server_draft(socket, draft_content, draft_updated_at)
  end

  defp subscribe_to_conversation(socket, conversation_id) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.conversation_topic(conversation_id))
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.typing_topic(conversation_id))
    end
  end

  defp load_relationship_data(socket, user_id, other_user_id) do
    relationship = Relationships.get_relationship(user_id, other_user_id)

    if connected?(socket) && relationship do
      Phoenix.PubSub.subscribe(
        Animina.PubSub,
        Relationships.relationship_topic(relationship.id)
      )
    end

    override =
      if relationship,
        do: Relationships.get_override(user_id, relationship.id),
        else: nil

    {relationship, override}
  end

  defp maybe_push_server_draft(socket, draft_content, draft_updated_at) do
    if connected?(socket) && draft_content do
      push_event(socket, "server_draft", %{
        content: draft_content,
        timestamp: DateTime.to_unix(draft_updated_at)
      })
    else
      socket
    end
  end

  defp handle_start_with(socket, target_id) do
    user = socket.assigns.current_scope.user

    # Check if conversation already exists (existing conversations are always accessible)
    case Messaging.get_conversation_by_participants(user.id, target_id) do
      %{id: conv_id} ->
        push_navigate(socket, to: ~p"/my/messages/#{conv_id}")

      nil ->
        initiate_new_conversation(socket, user.id, target_id)
    end
  end

  defp initiate_new_conversation(socket, user_id, target_id) do
    case Messaging.can_initiate_conversation?(user_id, target_id) do
      :ok ->
        create_and_navigate(socket, user_id, target_id)

      {:error, :chat_slots_full} ->
        put_flash(
          socket,
          :error,
          gettext("You have no free chat slots. Let go of a conversation first.")
        )

      {:error, :previously_closed} ->
        put_flash(socket, :error, gettext("This conversation was previously closed."))

      {:error, _reason} ->
        put_flash(socket, :error, gettext("Could not start conversation"))
    end
  end

  defp create_and_navigate(socket, user_id, target_id) do
    case Messaging.get_or_create_conversation(user_id, target_id) do
      {:ok, conversation} ->
        push_navigate(socket, to: ~p"/my/messages/#{conversation.id}")

      {:error, _reason} ->
        put_flash(socket, :error, gettext("Could not start conversation"))
    end
  end

  # --- Events ---

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    user = socket.assigns.current_scope.user
    conversation_data = socket.assigns.conversation_data

    if conversation_data && String.trim(content) != "" do
      case Messaging.send_message(conversation_data.conversation.id, user.id, content) do
        {:ok, _message} ->
          # Cancel pending draft save timer
          cancel_draft_timer(socket)

          # Message will be added via PubSub; draft cleared by context
          {:noreply,
           socket
           |> assign(:form, to_form(%{"content" => ""}, as: :message))
           |> assign(:draft_save_timer, nil)
           |> push_event("clear_draft", %{})}

        {:error, :blocked} ->
          {:noreply,
           put_flash(socket, :error, gettext("You cannot send messages in this conversation"))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message"))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("typing", %{"message" => %{"content" => content}}, socket) do
    conversation_data = socket.assigns.conversation_data
    user = socket.assigns.current_scope.user

    if conversation_data do
      typing? = String.trim(content) != ""
      Messaging.broadcast_typing(conversation_data.conversation.id, user.id, typing?)
    end

    # Schedule debounced draft save
    socket = schedule_draft_save(socket, content)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_draft", %{"content" => content}, socket) do
    save_draft_now(socket, content)
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_message", %{"id" => message_id}, socket) do
    user = socket.assigns.current_scope.user

    case Messaging.delete_message(message_id, user.id) do
      {:ok, _deleted} ->
        # Message removal will be handled by PubSub broadcast
        {:noreply, socket}

      {:error, :already_read} ->
        {:noreply,
         put_flash(socket, :error, gettext("Cannot delete a message that has been read"))}

      {:error, :delete_window_expired} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Messages can only be deleted within 15 minutes of sending")
         )}

      {:error, :other_user_online} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Cannot delete a message while the other person is online")
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete message"))}
    end
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
  def handle_event("let_go", %{"conversation-id" => conv_id}, socket) do
    {:noreply, assign(socket, :confirm_let_go_conv_id, conv_id)}
  end

  @impl true
  def handle_event("cancel_let_go", _params, socket) do
    {:noreply, assign(socket, :confirm_let_go_conv_id, nil)}
  end

  @impl true
  def handle_event("confirm_let_go", _params, socket) do
    conv_id = socket.assigns.confirm_let_go_conv_id
    user = socket.assigns.current_scope.user

    case Messaging.close_conversation(conv_id, user.id) do
      {:ok, _} ->
        socket =
          socket
          |> assign(:confirm_let_go_conv_id, nil)
          |> put_flash(:info, gettext("Conversation closed"))

        # Redirect to index if we were in the show view
        if socket.assigns.live_action == :show do
          {:noreply, push_navigate(socket, to: ~p"/my/messages")}
        else
          # Refresh the conversation list
          {:noreply, apply_action(socket, :index, %{})}
        end

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:confirm_let_go_conv_id, nil)
         |> put_flash(:error, gettext("Failed to close conversation"))}
    end
  end

  # --- Timeline events ---

  @impl true
  def handle_event("close_timeline", _params, socket) do
    {:noreply, assign(socket, :show_timeline, false)}
  end

  # --- Relationship action events ---

  @impl true
  def handle_event("relationship_action", %{"action" => action}, socket) do
    cond do
      proposal_status = proposal_target_status(action) ->
        do_propose_upgrade(socket, proposal_status)

      confirm = confirmation_dialog(action) ->
        {:noreply, assign(socket, :confirm_action, confirm)}

      true ->
        handle_direct_action(socket, action)
    end
  end

  @impl true
  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, :confirm_action, nil)}
  end

  @impl true
  def handle_event("execute_relationship_action", _params, socket) do
    {_title, _desc, _btn_label, target_status} = socket.assigns.confirm_action
    relationship = socket.assigns.relationship
    user_id = socket.assigns.current_scope.user.id

    case Relationships.transition_status(relationship, target_status, user_id) do
      {:ok, updated} ->
        socket =
          socket
          |> assign(relationship: updated, confirm_action: nil)
          |> put_flash(:info, gettext("Relationship updated"))

        # Redirect to index if conversation is now ended/blocked
        if target_status in ["ended", "blocked"] do
          {:noreply, push_navigate(socket, to: ~p"/my/messages")}
        else
          {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:confirm_action, nil)
         |> put_flash(:error, gettext("Could not update relationship"))}
    end
  end

  @impl true
  def handle_event("cancel_proposal", _params, socket) do
    relationship = socket.assigns.relationship
    user_id = socket.assigns.current_scope.user.id

    case Relationships.cancel_proposal(relationship, user_id) do
      {:ok, updated} ->
        {:noreply, assign(socket, :relationship, updated)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not cancel proposal"))}
    end
  end

  @impl true
  def handle_event("accept_proposal", _params, socket) do
    relationship = socket.assigns.relationship
    user_id = socket.assigns.current_scope.user.id

    case Relationships.accept_proposal(relationship, user_id) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:relationship, updated)
         |> put_flash(:info, gettext("Proposal accepted!"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not accept proposal"))}
    end
  end

  @impl true
  def handle_event("decline_proposal", _params, socket) do
    relationship = socket.assigns.relationship
    user_id = socket.assigns.current_scope.user.id

    case Relationships.decline_proposal(relationship, user_id) do
      {:ok, updated} ->
        {:noreply, assign(socket, :relationship, updated)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not decline proposal"))}
    end
  end

  @impl true
  def handle_event("close_override_modal", _params, socket) do
    {:noreply, assign(socket, :show_override_modal, false)}
  end

  @impl true
  def handle_event("save_overrides", params, socket) do
    relationship = socket.assigns.relationship
    user_id = socket.assigns.current_scope.user.id

    attrs = %{
      can_see_profile: params["can_see_profile"] == "true",
      can_message_me: params["can_message_me"] == "true",
      visible_in_discovery: params["visible_in_discovery"] == "true"
    }

    case Relationships.set_override(user_id, relationship.id, attrs) do
      {:ok, override} ->
        {:noreply,
         socket
         |> assign(override: override, show_override_modal: false)
         |> put_flash(:info, gettext("Permissions saved"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save permissions"))}
    end
  end

  @impl true
  def handle_event("love_emergency", %{"conversation-id" => conv_id}, socket) do
    user = socket.assigns.current_scope.user
    active_conversations = Messaging.list_conversations(user.id)
    cost = FeatureFlags.chat_love_emergency_cost()

    socket =
      assign(socket,
        show_love_emergency: true,
        love_emergency_conv_id: conv_id,
        love_emergency_active_conversations: active_conversations,
        love_emergency_selected: MapSet.new(),
        love_emergency_cost: cost
      )

    {:noreply, socket}
  end

  # --- PubSub handlers ---

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Real-time message received in the current conversation
    messages = socket.assigns.messages ++ [message]

    # Mark as read if we're viewing the conversation
    if socket.assigns.conversation_data do
      user = socket.assigns.current_scope.user
      Messaging.mark_as_read(socket.assigns.conversation_data.conversation.id, user.id)
    end

    last_read_message_id =
      find_last_read_message_id(
        messages,
        socket.assigns.current_scope.user.id,
        socket.assigns.other_last_read_at
      )

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:grouped_messages, group_messages(messages))
     |> assign(:last_read_message_id, last_read_message_id)}
  end

  @impl true
  def handle_info({:new_message, _conversation_id, _message}, socket) do
    # New message notification (we're on the index page or different conversation)
    # Refresh the conversation list if we're on index
    if socket.assigns.live_action == :index do
      user = socket.assigns.current_scope.user
      conversations = Messaging.list_conversations(user.id)
      {:noreply, assign(socket, :conversations, conversations)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_edited, message}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == message.id, do: message, else: m
      end)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:grouped_messages, group_messages(messages))}
  end

  @impl true
  def handle_info({:message_deleted, message}, socket) do
    messages = Enum.reject(socket.assigns.messages, fn m -> m.id == message.id end)

    last_read_message_id =
      find_last_read_message_id(
        messages,
        socket.assigns.current_scope.user.id,
        socket.assigns.other_last_read_at
      )

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:grouped_messages, group_messages(messages))
     |> assign(:last_read_message_id, last_read_message_id)}
  end

  @impl true
  def handle_info({:read_receipt, user_id}, socket) do
    # Update the other participant's last_read_at when they read our messages
    if socket.assigns.conversation_data &&
         user_id != socket.assigns.current_scope.user.id do
      conversation_id = socket.assigns.conversation_data.conversation.id
      current_user_id = socket.assigns.current_scope.user.id

      other_last_read_at =
        Messaging.get_other_participant_last_read(conversation_id, current_user_id)

      last_read_message_id =
        find_last_read_message_id(socket.assigns.messages, current_user_id, other_last_read_at)

      {:noreply,
       socket
       |> assign(:other_last_read_at, other_last_read_at)
       |> assign(:last_read_message_id, last_read_message_id)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:typing, user_id, typing?}, socket) do
    # Only show typing for the other user
    if socket.assigns.current_scope.user.id != user_id do
      # Cancel existing timer
      if socket.assigns.typing_timer do
        Process.cancel_timer(socket.assigns.typing_timer)
      end

      if typing? do
        timer = Process.send_after(self(), :clear_typing, 3_000)

        {:noreply,
         socket
         |> assign(:typing, true)
         |> assign(:typing_timer, timer)}
      else
        {:noreply,
         socket
         |> assign(:typing, false)
         |> assign(:typing_timer, nil)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_typing, socket) do
    {:noreply,
     socket
     |> assign(:typing, false)
     |> assign(:typing_timer, nil)}
  end

  @impl true
  def handle_info({:save_draft, content}, socket) do
    save_draft_now(socket, content)
    {:noreply, assign(socket, :draft_save_timer, nil)}
  end

  @impl true
  def handle_info({:unread_count_changed, _count}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_closed, _conversation_id}, socket) do
    # Refresh conversation list if on index
    if socket.assigns.live_action == :index do
      {:noreply, apply_action(socket, :index, %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:conversation_reopened, _conversation_id}, socket) do
    if socket.assigns.live_action == :index do
      {:noreply, apply_action(socket, :index, %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:love_emergency_complete, conv_id}, socket) do
    socket =
      socket
      |> assign(:show_love_emergency, false)
      |> assign(:love_emergency_conv_id, nil)
      |> put_flash(:info, gettext("Conversation reopened!"))

    {:noreply, push_navigate(socket, to: ~p"/my/messages/#{conv_id}")}
  end

  @impl true
  def handle_info({:love_emergency_error, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:show_love_emergency, false)
     |> put_flash(:error, gettext("Failed to reopen conversation"))}
  end

  @impl true
  def handle_info(:love_emergency_cancelled, socket) do
    {:noreply,
     socket
     |> assign(:show_love_emergency, false)
     |> assign(:love_emergency_conv_id, nil)}
  end

  @impl true
  def handle_info({:relationship_changed, relationship}, socket) do
    if socket.assigns.relationship && socket.assigns.relationship.id == relationship.id do
      socket = assign(socket, :relationship, relationship)

      # Refresh milestones if timeline is open
      socket =
        if socket.assigns.show_timeline do
          assign(socket, :milestones, Relationships.list_milestones(relationship.id))
        else
          socket
        end

      {:noreply, socket}
    else
      # On index page, refresh the relationship map
      if socket.assigns.live_action == :index do
        {:noreply, apply_action(socket, :index, %{})}
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info({:report_submitted, _reported_user_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_report_modal, false)
     |> put_flash(:info, gettext("Report submitted. Our team will review it."))
     |> push_navigate(to: ~p"/my/messages")}
  end

  @impl true
  def handle_info({:report_failed}, socket) do
    {:noreply,
     socket
     |> assign(:show_report_modal, false)
     |> put_flash(:error, gettext("Could not submit report. Please try again."))}
  end

  defp timeline_users(assigns) do
    user = assigns.current_scope.user
    other = assigns.conversation_data && assigns.conversation_data.other_user
    map = %{user.id => user}
    if other, do: Map.put(map, other.id, other), else: map
  end

  defp proposal_target_status("propose_dating"), do: "dating"
  defp proposal_target_status("propose_couple"), do: "couple"
  defp proposal_target_status("propose_marriage"), do: "married"
  defp proposal_target_status("propose_friend"), do: "friend"
  defp proposal_target_status(_action), do: nil

  defp confirmation_dialog("end_conversation") do
    {gettext("End this conversation?"),
     gettext("This will end the conversation. You will no longer see each other in discovery."),
     gettext("End Conversation"), "ended"}
  end

  defp confirmation_dialog("end_relationship") do
    {gettext("End this relationship?"), gettext("This will end the relationship."),
     gettext("End Relationship"), "ex"}
  end

  defp confirmation_dialog("separate") do
    {gettext("Separate?"), gettext("This will change your status to separated."),
     gettext("Separate"), "separated"}
  end

  defp confirmation_dialog("divorce") do
    {gettext("Divorce?"), gettext("This will finalize the divorce."), gettext("Divorce"),
     "divorced"}
  end

  defp confirmation_dialog("end_friendship") do
    {gettext("End this friendship?"), gettext("This will end the friendship."),
     gettext("End Friendship"), "ended"}
  end

  defp confirmation_dialog("block") do
    {gettext("Block this user?"),
     gettext("They will not be able to contact you or see your profile."), gettext("Block"),
     "blocked"}
  end

  defp confirmation_dialog("unblock") do
    {gettext("Unblock this user?"),
     gettext("This will end the relationship. You can start a new conversation later."),
     gettext("Unblock"), "ended"}
  end

  defp confirmation_dialog(_action), do: nil

  defp handle_direct_action(socket, "toggle_timeline") do
    if socket.assigns.show_timeline do
      {:noreply, assign(socket, :show_timeline, false)}
    else
      milestones =
        if socket.assigns.relationship,
          do: Relationships.list_milestones(socket.assigns.relationship.id),
          else: []

      {:noreply, assign(socket, show_timeline: true, milestones: milestones)}
    end
  end

  defp handle_direct_action(socket, "open_override_modal") do
    {:noreply, assign(socket, :show_override_modal, true)}
  end

  defp handle_direct_action(socket, "open_report_modal") do
    {:noreply, assign(socket, :show_report_modal, true)}
  end

  defp handle_direct_action(socket, _action) do
    {:noreply, socket}
  end

  defp do_propose_upgrade(socket, target_status) do
    relationship = socket.assigns.relationship
    user_id = socket.assigns.current_scope.user.id

    case Relationships.propose_upgrade(relationship, target_status, user_id) do
      {:ok, updated} ->
        {:noreply, assign(socket, :relationship, updated)}

      {:error, :proposal_already_pending} ->
        {:noreply, put_flash(socket, :error, gettext("A proposal is already pending"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not send proposal"))}
    end
  end

  defp schedule_draft_save(socket, content) do
    cancel_draft_timer(socket)
    timer = Process.send_after(self(), {:save_draft, content}, 2_000)
    assign(socket, :draft_save_timer, timer)
  end

  defp cancel_draft_timer(socket) do
    if socket.assigns.draft_save_timer do
      Process.cancel_timer(socket.assigns.draft_save_timer)
    end
  end

  defp save_draft_now(socket, content) do
    conversation_data = socket.assigns.conversation_data

    if conversation_data do
      user = socket.assigns.current_scope.user
      Messaging.save_draft(conversation_data.conversation.id, user.id, content)
    end
  end
end
