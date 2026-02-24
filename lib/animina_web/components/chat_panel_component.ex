defmodule AniminaWeb.ChatPanelComponent do
  @moduledoc """
  Side-panel chat component for the moodboard page.

  Renders as a fixed panel on the right (desktop) or a slide-in drawer (mobile).
  Conversation creation is lazy — no record is created until the first message is sent.

  Communication pattern:
  - Parent sends `send_update(ChatPanelComponent, id: "chat-panel", chat_event: {...})`
  - Component sends `send(self(), {:chat_panel_subscribe, conversation_id})` on first message
  - Component sends `send(self(), :close_chat_panel)` on close
  """

  use AniminaWeb, :live_component

  import AniminaWeb.MessageComponents

  alias Animina.Accounts
  alias Animina.FeatureFlags
  alias Animina.Messaging
  alias Animina.Photos
  alias Animina.Wingman

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       messages: [],
       grouped_messages: [],
       form: to_form(%{"content" => ""}, as: :message),
       typing: false,
       other_last_read_at: nil,
       last_read_message_id: nil,
       blocked: false,
       avatar_photos: %{},
       loaded: false,
       wingman_suggestions: nil,
       wingman_loading: false,
       wingman_dismissed: false,
       wingman_feedback: %{},
       wingman_job_id: nil,
       wingman_available: false,
       wingman_enabled: true,
       wingman_expiry_timer: nil,
       spellcheck_loading: false,
       spellcheck_original: nil,
       last_spellchecked_text: nil
     )}
  end

  @impl true
  def update(%{chat_event: {:new_message, message}}, socket) do
    # Deduplicate: sender already added the message locally in deliver_message
    if Enum.any?(socket.assigns.messages, &(&1.id == message.id)) do
      {:ok, socket}
    else
      messages = socket.assigns.messages ++ [message]

      # Mark as read since panel is open
      if socket.assigns.conversation_id do
        Messaging.mark_as_read(socket.assigns.conversation_id, socket.assigns.current_user_id)
      end

      {:ok,
       socket
       |> assign(:messages, messages)
       |> assign(:grouped_messages, group_messages(messages))
       |> update_last_read_message_id()}
    end
  end

  def update(%{chat_event: {:message_edited, message}}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == message.id, do: message, else: m
      end)

    {:ok,
     socket
     |> assign(:messages, messages)
     |> assign(:grouped_messages, group_messages(messages))}
  end

  def update(%{chat_event: {:message_deleted, message}}, socket) do
    messages = Enum.reject(socket.assigns.messages, fn m -> m.id == message.id end)

    {:ok,
     socket
     |> assign(:messages, messages)
     |> assign(:grouped_messages, group_messages(messages))
     |> update_last_read_message_id()}
  end

  def update(%{chat_event: {:read_receipt, user_id}}, socket) do
    if user_id != socket.assigns.current_user_id && socket.assigns.conversation_id do
      other_last_read_at =
        Messaging.get_other_participant_last_read(
          socket.assigns.conversation_id,
          socket.assigns.current_user_id
        )

      {:ok,
       socket
       |> assign(:other_last_read_at, other_last_read_at)
       |> update_last_read_message_id()}
    else
      {:ok, socket}
    end
  end

  def update(%{chat_event: {:typing, _user_id}}, socket) do
    {:ok, assign(socket, :typing, true)}
  end

  def update(%{chat_event: :clear_typing}, socket) do
    {:ok, assign(socket, :typing, false)}
  end

  def update(%{chat_event: {:wingman_ready, suggestions}}, socket) do
    {:ok,
     socket
     |> assign(:wingman_suggestions, suggestions)
     |> assign(:wingman_loading, false)}
  end

  def update(%{chat_event: {:wingman_expiry_check, job_id}}, socket) do
    if socket.assigns.wingman_loading && socket.assigns.wingman_job_id == job_id do
      job = Animina.AI.get_job(job_id)

      if job && job.status in ~w(cancelled failed) do
        {:ok,
         socket
         |> assign(:wingman_loading, false)
         |> assign(:wingman_suggestions, nil)
         |> assign(:wingman_dismissed, true)}
      else
        {:ok, socket}
      end
    else
      {:ok, socket}
    end
  end

  def update(%{chat_event: {:spellcheck_done, original, corrected}}, socket) do
    {:ok,
     socket
     |> assign(:spellcheck_loading, false)
     |> assign(:spellcheck_original, original)
     |> assign(:last_spellchecked_text, String.trim(corrected))
     |> assign(:form, to_form(%{"content" => corrected}, as: :message))}
  end

  def update(%{chat_event: :spellcheck_unchanged}, socket) do
    content = socket.assigns.form[:content].value

    {:ok,
     socket
     |> assign(:spellcheck_loading, false)
     |> assign(:last_spellchecked_text, String.trim(content || ""))}
  end

  def update(%{chat_event: :spellcheck_error}, socket) do
    {:ok, assign(socket, :spellcheck_loading, false)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:current_user_id, assigns.current_user_id)
      |> assign(:profile_user, assigns.profile_user)
      |> assign(:open, assigns.open)
      |> assign(:conversation_id, assigns.conversation_id)
      |> maybe_load_conversation(assigns)
      |> maybe_load_avatar(assigns)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="chat-panel"
      phx-hook="ChatPanel"
      data-open={to_string(@open)}
      class={[
        "fixed inset-0 z-40 transition-all duration-300",
        if(@open, do: "pointer-events-auto", else: "pointer-events-none")
      ]}
    >
      <%!-- Mobile backdrop --%>
      <div
        class={[
          "lg:hidden absolute inset-0 bg-black/40 transition-opacity duration-300",
          if(@open, do: "opacity-100", else: "opacity-0")
        ]}
        phx-click="close_panel"
        phx-target={@myself}
      />

      <%!-- Panel --%>
      <div class={[
        "absolute top-16 right-0 bottom-0 w-full sm:w-[380px] bg-base-100 shadow-2xl border-l border-base-300 flex flex-col transition-transform duration-300",
        if(@open, do: "translate-x-0", else: "translate-x-full")
      ]}>
        <%!-- Header --%>
        <div class="flex items-center gap-3 px-4 py-3 border-b border-base-300 bg-base-100">
          <button
            phx-click="close_panel"
            phx-target={@myself}
            class="btn btn-ghost btn-sm btn-circle"
            aria-label={gettext("Close")}
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>

          <.link
            navigate={~p"/users/#{@profile_user.id}"}
            class="flex items-center gap-2 flex-1 min-w-0"
          >
            <.user_avatar
              user={@profile_user}
              photos={@avatar_photos}
              size={:xs}
            />
            <span class="font-semibold truncate">{@profile_user.display_name}</span>
          </.link>

          <div :if={@typing} class="text-xs text-primary animate-pulse">
            {gettext("typing...")}
          </div>

          <.link
            navigate={
              if(@conversation_id,
                do: ~p"/my/messages/#{@conversation_id}",
                else: ~p"/my/messages?start_with=#{@profile_user.id}"
              )
            }
            class="btn btn-ghost btn-sm btn-circle"
            title={gettext("Open full chat")}
          >
            <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
          </.link>
        </div>

        <%!-- Messages --%>
        <div
          id="chat-panel-messages"
          class="flex-1 overflow-y-auto px-4 py-3"
          phx-hook="ScrollToBottom"
        >
          <%= if Enum.empty?(@messages) do %>
            <div class="text-center py-8 text-base-content/50">
              <.icon name="hero-chat-bubble-left-right" class="h-10 w-10 mx-auto mb-3 opacity-50" />
              <p class="text-sm">{gettext("Send a message to start the conversation")}</p>
            </div>
          <% else %>
            <.message_group
              :for={group <- @grouped_messages}
              group={group}
              current_user_id={@current_user_id}
              other_last_read_at={@other_last_read_at}
              last_read_message_id={@last_read_message_id}
              myself={@myself}
            />
          <% end %>
        </div>

        <%!-- Wingman Card --%>
        <div
          :if={@wingman_suggestions != nil && !@wingman_dismissed}
          class="mx-2 mb-2 p-2.5 bg-info/5 rounded-lg border border-info/20"
        >
          <div class="flex items-center justify-between mb-1.5">
            <span class="text-xs font-medium text-info">
              {gettext("Wingman")}
            </span>
            <button phx-click="dismiss_wingman" phx-target={@myself} class="btn btn-ghost btn-xs">
              <.icon name="hero-x-mark" class="h-3 w-3" />
            </button>
          </div>
          <div class="space-y-1.5">
            <div
              :for={{suggestion, idx} <- Enum.with_index(@wingman_suggestions)}
              class="bg-base-100 rounded-lg overflow-hidden border border-base-300"
            >
              <div class="p-2.5">
                <p class="text-xs font-medium">{suggestion["text"]}</p>
              </div>
              <div
                :if={suggestion["hook"]}
                class="flex items-start gap-1.5 px-2.5 py-1.5 bg-base-200/50 border-t border-base-300/50"
              >
                <span class="text-sm mt-0.5 shrink-0">💡</span>
                <p class="text-xs text-base-content/70 italic">{suggestion["hook"]}</p>
              </div>
              <div class="flex items-center gap-1 px-2.5 py-1 border-t border-base-300/30">
                <button
                  phx-click="wingman_feedback"
                  phx-value-index={idx}
                  phx-value-rating="1"
                  phx-target={@myself}
                  class={[
                    "btn btn-ghost btn-xs btn-circle",
                    if(Map.get(@wingman_feedback, idx) == 1,
                      do: "text-success bg-success/20",
                      else: "text-base-content/30 hover:text-success hover:bg-success/10"
                    )
                  ]}
                  title={gettext("Helpful")}
                >
                  <.icon name="hero-hand-thumb-up-mini" class="h-3 w-3" />
                </button>
                <button
                  phx-click="wingman_feedback"
                  phx-value-index={idx}
                  phx-value-rating="-1"
                  phx-target={@myself}
                  class={[
                    "btn btn-ghost btn-xs btn-circle",
                    if(Map.get(@wingman_feedback, idx) == -1,
                      do: "text-error bg-error/20",
                      else: "text-base-content/30 hover:text-error hover:bg-error/10"
                    )
                  ]}
                  title={gettext("Not helpful")}
                >
                  <.icon name="hero-hand-thumb-down-mini" class="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Wingman Loading --%>
        <div
          :if={@wingman_loading && !@wingman_dismissed}
          class="mx-2 mb-2 p-2.5 bg-info/5 rounded-lg border border-info/20"
        >
          <div class="flex items-center justify-between mb-1.5">
            <div class="flex items-center gap-1.5">
              <span class="loading loading-spinner loading-xs text-info"></span>
              <span class="text-xs font-medium text-info">
                {gettext("Wingman is thinking...")}
              </span>
            </div>
            <button phx-click="dismiss_wingman" phx-target={@myself} class="btn btn-ghost btn-xs">
              <.icon name="hero-x-mark" class="h-3 w-3" />
            </button>
          </div>
          <progress class="progress progress-info w-full h-1.5 mt-1" />
        </div>

        <%!-- Wingman Toggle --%>
        <div
          :if={@wingman_available && Enum.empty?(@messages)}
          class="flex items-center justify-between mx-2 mb-1 px-2.5 py-1.5 rounded-lg bg-base-200/50"
        >
          <span class="text-xs text-base-content/60">
            {gettext("Wingman")}
          </span>
          <label class="cursor-pointer flex items-center gap-1.5">
            <span class="text-xs text-base-content/40">
              {if @wingman_enabled, do: gettext("On"), else: gettext("Off")}
            </span>
            <input
              type="checkbox"
              class="toggle toggle-xs toggle-info"
              checked={@wingman_enabled}
              phx-click="toggle_wingman"
              phx-target={@myself}
            />
          </label>
        </div>

        <%!-- Input --%>
        <.chat_input
          form={@form}
          input_id="chat-panel-input"
          form_id="chat-panel-form"
          draft_key={"draft:#{@current_user_id}:#{@profile_user.id}"}
          blocked={@blocked}
          size={:sm}
          phx_target={@myself}
          typing_event="chat_typing"
          spellcheck_enabled={FeatureFlags.spellcheck_available?()}
          spellcheck_loading={@spellcheck_loading}
          spellcheck_has_undo={@spellcheck_original != nil}
        />
      </div>
    </div>
    """
  end

  # --- Message rendering components ---

  attr :group, :map, required: true
  attr :current_user_id, :string, required: true
  attr :other_last_read_at, :any, default: nil
  attr :last_read_message_id, :string, default: nil
  attr :myself, :any, required: true

  defp message_group(assigns) do
    ~H"""
    <div class="flex items-center gap-3 my-3">
      <div class="flex-1 border-t border-base-300" />
      <span class="text-xs text-base-content/60 font-medium">{@group.date_label}</span>
      <div class="flex-1 border-t border-base-300" />
    </div>

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
        myself={@myself}
      />
    </div>
    """
  end

  attr :message, :map, required: true
  attr :is_sender, :boolean, required: true
  attr :is_first, :boolean, default: true
  attr :is_last, :boolean, default: true
  attr :show_time, :boolean, default: true
  attr :is_read, :boolean, default: false
  attr :read_at, :any, default: nil
  attr :myself, :any, required: true

  defp message_bubble(assigns) do
    ~H"""
    <div class={[
      "flex group",
      @is_sender && "justify-end",
      if(@is_first, do: "mt-2", else: "mt-0.5")
    ]}>
      <div class="relative max-w-[85%]">
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
                <span class="ml-0.5">
                  <.icon name="hero-check" class="h-3 w-3 inline" /><.icon
                    name="hero-check"
                    class="h-3 w-3 inline -ml-1.5"
                  />
                </span>
              <% else %>
                <span class="ml-0.5" title={gettext("Sent")}>
                  <.icon name="hero-check" class="h-3 w-3 inline opacity-60" />
                </span>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Delete button for own unread messages --%>
        <%= if @is_sender do %>
          <button
            phx-click="delete_message"
            phx-value-id={@message.id}
            phx-target={@myself}
            data-confirm={gettext("Delete this message?")}
            class="absolute -left-7 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-opacity btn btn-ghost btn-xs btn-circle"
            title={gettext("Delete")}
          >
            <.icon name="hero-trash" class="h-3 w-3 text-error" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp bubble_classes(true = _sender, first, last),
    do: ["px-3 py-1.5", "bg-primary text-primary-content", bubble_radius("r", "b", first, last)]

  defp bubble_classes(false = _sender, first, last),
    do: ["px-3 py-1.5", "bg-base-200 text-base-content", bubble_radius("l", "b", first, last)]

  defp bubble_radius(side, corner, true, true), do: "rounded-2xl rounded-#{corner}#{side}-md"
  defp bubble_radius(side, corner, true, false), do: "rounded-2xl rounded-#{corner}#{side}-sm"

  defp bubble_radius(side, corner, false, true),
    do: "rounded-2xl rounded-t#{side}-sm rounded-#{corner}#{side}-md"

  defp bubble_radius(side, _corner, false, false), do: "rounded-2xl rounded-#{side}-sm"

  # --- Event handlers ---

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content)

    if content != "" do
      do_send_message(content, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("chat_typing", %{"message" => %{"content" => content}}, socket) do
    if socket.assigns.conversation_id do
      typing? = String.trim(content) != ""

      Messaging.broadcast_typing(
        socket.assigns.conversation_id,
        socket.assigns.current_user_id,
        typing?
      )
    end

    {:noreply, assign(socket, :form, to_form(%{"content" => content}, as: :message))}
  end

  def handle_event("save_draft", %{"content" => content}, socket) do
    if socket.assigns.conversation_id do
      Messaging.save_draft(
        socket.assigns.conversation_id,
        socket.assigns.current_user_id,
        content
      )
    end

    {:noreply, socket}
  end

  def handle_event("delete_message", %{"id" => message_id}, socket) do
    case Messaging.delete_message(message_id, socket.assigns.current_user_id) do
      {:ok, _deleted} ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("dismiss_wingman", _params, socket) do
    {:noreply, assign(socket, :wingman_dismissed, true)}
  end

  def handle_event("toggle_wingman", _params, socket) do
    user = Accounts.get_user!(socket.assigns.current_user_id)
    new_value = !user.wingman_enabled

    case Accounts.update_wingman_enabled(user, %{wingman_enabled: new_value}) do
      {:ok, _updated} ->
        socket =
          socket
          |> assign(:wingman_enabled, new_value)
          |> maybe_dismiss_wingman(new_value)

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("wingman_feedback", %{"index" => idx_str, "rating" => rating_str}, socket) do
    idx = String.to_integer(idx_str)
    value = String.to_integer(rating_str)
    suggestion = Enum.at(socket.assigns.wingman_suggestions || [], idx)

    if suggestion && socket.assigns.conversation_id do
      suggestion_data = %{
        text: suggestion["text"],
        hook: suggestion["hook"]
      }

      Wingman.toggle_feedback(
        socket.assigns.current_user_id,
        socket.assigns.conversation_id,
        idx,
        value,
        suggestion_data
      )

      feedback_map =
        Wingman.get_feedback_for_suggestions(
          socket.assigns.current_user_id,
          socket.assigns.conversation_id
        )

      {:noreply, assign(socket, :wingman_feedback, feedback_map)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("spellcheck", _params, socket) do
    content = socket.assigns.form[:content].value

    if is_binary(content) && String.trim(content) != "" && FeatureFlags.spellcheck_available?() do
      trimmed = String.trim(content)

      if trimmed == socket.assigns.last_spellchecked_text do
        {:noreply, socket}
      else
        send(self(), {:chat_panel_spellcheck, socket.assigns.id, trimmed})
        {:noreply, assign(socket, :spellcheck_loading, true)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("undo_spellcheck", _params, socket) do
    case socket.assigns.spellcheck_original do
      nil ->
        {:noreply, socket}

      original ->
        {:noreply,
         socket
         |> assign(:spellcheck_original, nil)
         |> assign(:last_spellchecked_text, nil)
         |> assign(:form, to_form(%{"content" => original}, as: :message))}
    end
  end

  def handle_event("close_panel", _params, socket) do
    # Save draft to server before closing so it persists on reopen
    content = socket.assigns.form[:content].value

    if socket.assigns.conversation_id && content != "" do
      Messaging.save_draft(
        socket.assigns.conversation_id,
        socket.assigns.current_user_id,
        content
      )
    end

    send(self(), :close_chat_panel)
    {:noreply, socket}
  end

  # --- Helpers ---

  defp do_send_message(content, socket) do
    current_user_id = socket.assigns.current_user_id

    {conversation_id, socket} = ensure_conversation(socket)

    if conversation_id do
      deliver_message(conversation_id, current_user_id, content, socket)
    else
      {:noreply, socket}
    end
  end

  defp ensure_conversation(socket) do
    if socket.assigns.conversation_id do
      {socket.assigns.conversation_id, socket}
    else
      create_or_deny_conversation(socket)
    end
  end

  defp create_or_deny_conversation(socket) do
    current_user_id = socket.assigns.current_user_id
    profile_user_id = socket.assigns.profile_user.id

    case Messaging.can_initiate_conversation?(current_user_id, profile_user_id) do
      :ok ->
        do_create_conversation(socket, current_user_id, profile_user_id)

      {:error, :chat_slots_full} ->
        send(
          self(),
          {:chat_panel_error,
           gettext("You have no free chat slots. Let go of a conversation first.")}
        )

        {nil, socket}

      {:error, :previously_closed} ->
        send(self(), {:chat_panel_error, gettext("This conversation was previously closed.")})
        {nil, socket}

      {:error, _reason} ->
        {nil, socket}
    end
  end

  defp do_create_conversation(socket, current_user_id, profile_user_id) do
    case Messaging.get_or_create_conversation(current_user_id, profile_user_id) do
      {:ok, conversation} ->
        send(self(), {:chat_panel_subscribe, conversation.id})
        {conversation.id, assign(socket, :conversation_id, conversation.id)}

      {:error, _reason} ->
        {nil, socket}
    end
  end

  defp deliver_message(conversation_id, current_user_id, content, socket) do
    case Messaging.send_message(conversation_id, current_user_id, content) do
      {:ok, message} ->
        # Add message to local state immediately — don't rely solely on PubSub
        # which may not be subscribed yet (race condition on new conversations)
        messages = socket.assigns.messages ++ [message]

        # Clear wingman after first message
        socket =
          if socket.assigns.wingman_suggestions || socket.assigns.wingman_loading do
            Wingman.delete_suggestions(conversation_id, current_user_id)

            socket
            |> assign(:wingman_suggestions, nil)
            |> assign(:wingman_loading, false)
            |> assign(:wingman_dismissed, true)
          else
            socket
          end

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(:grouped_messages, group_messages(messages))
         |> assign(:form, to_form(%{"content" => ""}, as: :message))
         |> assign(:spellcheck_original, nil)
         |> assign(:last_spellchecked_text, nil)
         |> update_last_read_message_id()}

      {:error, :blocked} ->
        {:noreply, assign(socket, :blocked, true)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp maybe_load_conversation(socket, %{open: true, conversation_id: cid} = assigns)
       when not is_nil(cid) do
    if socket.assigns.loaded do
      socket
    else
      load_conversation_data(socket, assigns)
    end
  end

  defp maybe_load_conversation(socket, %{open: true} = assigns) do
    if socket.assigns.loaded do
      socket
    else
      socket = assign(socket, :loaded, true)
      maybe_init_wingman(socket, assigns, [])
    end
  end

  defp maybe_load_conversation(socket, _assigns), do: socket

  defp load_conversation_data(socket, assigns) do
    messages =
      Messaging.list_messages(assigns.conversation_id, assigns.current_user_id)

    Messaging.mark_as_read(assigns.conversation_id, assigns.current_user_id)

    other_last_read_at =
      Messaging.get_other_participant_last_read(
        assigns.conversation_id,
        assigns.current_user_id
      )

    blocked =
      Messaging.blocked_in_conversation?(assigns.conversation_id, assigns.current_user_id)

    form_content = resolve_draft_content(socket, assigns)

    socket =
      socket
      |> assign(:messages, messages)
      |> assign(:grouped_messages, group_messages(messages))
      |> assign(:other_last_read_at, other_last_read_at)
      |> assign(:blocked, blocked)
      |> assign(:loaded, true)
      |> assign(:form, to_form(%{"content" => form_content}, as: :message))
      |> update_last_read_message_id()

    maybe_init_wingman(socket, assigns, messages)
  end

  defp resolve_draft_content(socket, assigns) do
    current_content = socket.assigns.form[:content].value

    if current_content != nil && current_content != "" do
      current_content
    else
      {draft_content, _draft_updated_at} =
        Messaging.get_draft(assigns.conversation_id, assigns.current_user_id)

      draft_content || ""
    end
  end

  defp maybe_init_wingman(socket, assigns, messages) do
    wingman_available = FeatureFlags.wingman_available?()
    user = Accounts.get_user!(assigns.current_user_id)

    socket =
      socket
      |> assign(:wingman_available, wingman_available)
      |> assign(:wingman_enabled, user.wingman_enabled)

    if wingman_available && user.wingman_enabled && Enum.empty?(messages) do
      do_init_wingman(socket, assigns)
    else
      socket
    end
  end

  defp do_init_wingman(socket, assigns) do
    current_user_id = assigns.current_user_id
    profile_user_id = assigns.profile_user.id

    {conversation_id, socket} =
      case assigns[:conversation_id] do
        nil ->
          eagerly_create_conversation(socket, current_user_id, profile_user_id)

        cid ->
          {cid, socket}
      end

    load_wingman_suggestions(socket, conversation_id, current_user_id, profile_user_id)
  end

  defp load_wingman_suggestions(socket, nil, _current_user_id, _profile_user_id), do: socket

  defp load_wingman_suggestions(socket, conversation_id, current_user_id, profile_user_id) do
    send(self(), {:chat_panel_wingman_subscribe, conversation_id, current_user_id})

    feedback_map = Wingman.get_feedback_for_suggestions(current_user_id, conversation_id)

    case Wingman.get_or_generate_suggestions(
           conversation_id,
           current_user_id,
           profile_user_id
         ) do
      {:ok, suggestions} ->
        assign(socket,
          wingman_suggestions: suggestions,
          wingman_loading: false,
          wingman_feedback: feedback_map
        )

      {:pending, job_id} ->
        # Schedule expiry check slightly after the 60s job expiry
        expiry_timer = Process.send_after(self(), {:wingman_expiry_check, job_id}, 65_000)

        assign(socket,
          wingman_loading: true,
          wingman_feedback: feedback_map,
          wingman_job_id: job_id,
          wingman_expiry_timer: expiry_timer
        )

      {:error, _reason} ->
        socket
    end
  end

  defp eagerly_create_conversation(socket, current_user_id, profile_user_id) do
    case Messaging.can_initiate_conversation?(current_user_id, profile_user_id) do
      :ok ->
        case Messaging.get_or_create_conversation(current_user_id, profile_user_id) do
          {:ok, conversation} ->
            send(self(), {:chat_panel_subscribe, conversation.id})
            {conversation.id, assign(socket, :conversation_id, conversation.id)}

          {:error, _reason} ->
            {nil, socket}
        end

      {:error, _reason} ->
        {nil, socket}
    end
  end

  defp maybe_dismiss_wingman(socket, true), do: socket

  defp maybe_dismiss_wingman(socket, false) do
    socket
    |> assign(:wingman_suggestions, nil)
    |> assign(:wingman_loading, false)
    |> assign(:wingman_dismissed, true)
  end

  defp maybe_load_avatar(socket, assigns) do
    if socket.assigns.avatar_photos == %{} do
      photo = Photos.get_user_avatar(assigns.profile_user.id)
      photos = if photo, do: %{assigns.profile_user.id => photo}, else: %{}
      assign(socket, :avatar_photos, photos)
    else
      socket
    end
  end

  defp update_last_read_message_id(socket) do
    last_read_message_id =
      find_last_read_message_id(
        socket.assigns.messages,
        socket.assigns.current_user_id,
        socket.assigns.other_last_read_at
      )

    assign(socket, :last_read_message_id, last_read_message_id)
  end

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

  # --- Message grouping ---

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

  # --- Formatting ---

  defp format_date_label(date) do
    today = Animina.TimeMachine.utc_today()
    diff = Date.diff(today, date)

    cond do
      diff == 0 -> gettext("Today")
      diff == 1 -> gettext("Yesterday")
      diff < 7 -> Calendar.strftime(date, "%A")
      true -> Calendar.strftime(date, "%d.%m.%Y")
    end
  end

  defp format_message_time(datetime) do
    now = Animina.TimeMachine.utc_now()
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
end
