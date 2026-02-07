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

  alias Animina.Messaging
  alias Animina.Photos
  alias AniminaWeb.Helpers.AvatarHelpers

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto flex flex-col h-[calc(100vh-12rem)]">
        <%!-- Conversation Header --%>
        <div class="flex items-center gap-3 pb-4 border-b border-base-300">
          <.link navigate={~p"/messages"} class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-arrow-left" class="h-5 w-5" />
          </.link>

          <%= if @conversation_data do %>
            <.link
              navigate={~p"/moodboard/#{@conversation_data.other_user.id}"}
              class="flex items-center gap-3 hover:opacity-80 transition-opacity"
            >
              <.avatar user={@conversation_data.other_user} photos={@avatar_photos} size={:sm} />
              <div>
                <div class="font-semibold">{@conversation_data.other_user.display_name}</div>
                <div :if={@typing} class="text-xs text-primary animate-pulse">
                  {gettext("typing...")}
                </div>
              </div>
            </.link>

            <div class="flex-1" />

            <%= if @conversation_data.blocked do %>
              <span class="badge badge-error badge-sm">{gettext("Blocked")}</span>
            <% end %>
          <% end %>
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
    </Layouts.app>
    """
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
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
              <.link navigate={~p"/discover"} class="btn btn-primary btn-sm mt-4">
                <.icon name="hero-magnifying-glass" class="h-4 w-4" />
                {gettext("Discover")}
              </.link>
            </div>
          <% else %>
            <div class="divide-y divide-base-300">
              <.conversation_row
                :for={conv <- @conversations}
                conversation={conv}
                avatar_photos={@avatar_photos}
              />
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Conversation row component ---

  attr :conversation, :map, required: true
  attr :avatar_photos, :map, required: true

  defp conversation_row(assigns) do
    ~H"""
    <.link
      navigate={~p"/messages/#{@conversation.conversation.id}"}
      class={[
        "flex items-center gap-3 p-4 hover:bg-base-200 transition-colors -mx-4",
        @conversation.unread && "bg-primary/5"
      ]}
    >
      <.avatar user={@conversation.other_user} photos={@avatar_photos} size={:md} />

      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class={["font-medium truncate", @conversation.unread && "font-semibold"]}>
            {@conversation.other_user.display_name}
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
    """
  end

  # --- Message group component (date separator + grouped bubbles) ---

  attr :group, :map, required: true
  attr :current_user_id, :string, required: true
  attr :other_user, :map, default: nil
  attr :other_last_read_at, :any, default: nil
  attr :last_read_message_id, :string, default: nil

  defp message_group(assigns) do
    ~H"""
    <%!-- Date separator --%>
    <div class="flex items-center gap-3 my-4">
      <div class="flex-1 border-t border-base-300" />
      <span class="text-xs text-base-content/40 font-medium">{@group.date_label}</span>
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

  defp message_bubble(assigns) do
    ~H"""
    <div class={[
      "flex group",
      @is_sender && "justify-end",
      if(@is_first, do: "mt-2", else: "mt-0.5")
    ]}>
      <div class="relative max-w-[80%]">
        <div class={bubble_classes(@is_sender, @is_first, @is_last)}>
          <div class={[
            "prose prose-sm max-w-none break-words [&>p]:my-0.5",
            if(@is_sender, do: "prose-invert", else: "")
          ]}>
            {render_markdown(@message.content)}
          </div>
          <div
            :if={@show_time}
            class={[
              "text-xs mt-1 flex items-center gap-1",
              if(@is_sender, do: "text-primary-content/60 justify-end", else: "text-base-content/40")
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

        <%!-- Delete button for own unread messages --%>
        <%= if @is_sender do %>
          <button
            id={"delete-message-#{@message.id}"}
            phx-click="delete_message"
            phx-value-id={@message.id}
            data-confirm={gettext("Delete this message?")}
            class="absolute -left-8 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-opacity btn btn-ghost btn-xs btn-circle"
            title={gettext("Delete")}
          >
            <.icon name="hero-trash" class="h-3.5 w-3.5 text-error" />
          </button>
        <% end %>
      </div>
    </div>
    """
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

  # --- Avatar component ---

  attr :user, :map, required: true
  attr :photos, :map, required: true
  attr :size, :atom, default: :md

  defp avatar(assigns) do
    avatar_photo = Map.get(assigns.photos, assigns.user.id)

    size_class =
      case assigns.size do
        :sm -> "w-10 h-10"
        :md -> "w-12 h-12"
        :lg -> "w-16 h-16"
      end

    assigns =
      assigns
      |> assign(:avatar_photo, avatar_photo)
      |> assign(:size_class, size_class)

    ~H"""
    <%= if @avatar_photo do %>
      <img
        src={Photos.signed_url(@avatar_photo)}
        alt={@user.display_name}
        class={[@size_class, "rounded-full object-cover"]}
      />
    <% else %>
      <div class={[@size_class, "rounded-full bg-primary/10 flex items-center justify-center"]}>
        <span class="text-primary font-semibold">{String.first(@user.display_name)}</span>
      </div>
    <% end %>
    """
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
        form: to_form(%{"content" => ""}, as: :message)
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

    assign(socket,
      page_title: gettext("Messages"),
      conversations: conversations,
      conversation_data: nil,
      messages: [],
      grouped_messages: [],
      avatar_photos: AvatarHelpers.load_from_conversations(conversations),
      other_last_read_at: nil,
      last_read_message_id: nil
    )
  end

  defp apply_action(socket, :show, %{"conversation_id" => conversation_id}) do
    user = socket.assigns.current_scope.user

    case Messaging.get_conversation_for_user(conversation_id, user.id) do
      nil ->
        socket
        |> put_flash(:error, gettext("Conversation not found"))
        |> redirect(to: ~p"/messages")

      conversation_data ->
        # Subscribe to conversation updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.conversation_topic(conversation_id))
          Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.typing_topic(conversation_id))
        end

        # Mark as read
        Messaging.mark_as_read(conversation_id, user.id)

        messages = Messaging.list_messages(conversation_id, user.id)
        other_last_read_at = Messaging.get_other_participant_last_read(conversation_id, user.id)
        last_read_message_id = find_last_read_message_id(messages, user.id, other_last_read_at)

        other_user = conversation_data.other_user

        # Load server-side draft
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
            form: to_form(%{"content" => form_content}, as: :message)
          )

        # Push server draft to JS for timestamp comparison
        if connected?(socket) && draft_content do
          push_event(socket, "server_draft", %{
            content: draft_content,
            timestamp: DateTime.to_unix(draft_updated_at)
          })
        else
          socket
        end
    end
  end

  defp handle_start_with(socket, target_id) do
    user = socket.assigns.current_scope.user

    case Messaging.get_or_create_conversation(user.id, target_id) do
      {:ok, conversation} ->
        push_navigate(socket, to: ~p"/messages/#{conversation.id}")

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

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete message"))}
    end
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
