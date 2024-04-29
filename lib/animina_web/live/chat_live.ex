defmodule AniminaWeb.ChatLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Message
  alias Animina.Accounts.Points
  alias Animina.Accounts.Reaction
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(%{"profile" => profile} = params, %{"language" => language} = _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.username}"
      )
    end

    sender =
      if params["current_user"] do
        {:ok, sender} = Accounts.User.by_username(params["current_user"])
        sender
      else
        socket.assigns.current_user
      end

    {:ok, receiver} = Accounts.User.by_username(profile)

    {:ok, messages_between_sender_and_receiver} =
      Message.messages_for_sender_and_receiver(sender.id, receiver.id, actor: sender)

    intersecting_green_flags_count =
      get_intersecting_flags_count(
        filter_flags(sender, :green, language),
        filter_flags(receiver, :white, language)
      )

    intersecting_red_flags_count =
      get_intersecting_flags_count(
        filter_flags(sender, :red, language),
        filter_flags(receiver, :white, language)
      )

    # we make sure that the messages are marked as read when the user visits the chat page
    update_read_at_messages(messages_between_sender_and_receiver, sender)

    socket =
      socket
      |> assign(active_tab: :chat)
      |> assign(sender: sender)
      |> assign(:messages, messages_between_sender_and_receiver)
      |> assign(receiver: receiver)
      |> assign(:language, language)
      |> assign(:unread_messages, [])
      |> assign(profile_points: Points.humanized_points(receiver.credit_points))
      |> assign(:intersecting_green_flags_count, intersecting_green_flags_count)
      |> assign(:intersecting_red_flags_count, intersecting_red_flags_count)
      |> assign(:number_of_unread_messages, 0)
      |> assign(form: create_message_form())
      |> assign(
        current_user_has_liked_profile?: current_user_has_liked_profile(sender.id, receiver.id)
      )
      |> assign(page_title: "#{sender.username} <-> #{receiver.username} (animina chat)")

    if profile != Ash.CiString.value(socket.assigns.receiver.username) or
         params["current_user"] != Ash.CiString.value(socket.assigns.sender.username) do
      {:ok,
       socket
       |> push_redirect(
         to: ~p"/#{socket.assigns.sender.username}/messages/#{socket.assigns.receiver.username}"
       )}
    else
      {:ok, socket}
    end
  end

  defp update_read_at_messages(messages, sender) do
    Enum.each(messages, fn message ->
      if message.receiver_id == sender.id and message.read_at == nil do
        Message.has_been_read(message, actor: sender)
      end
    end)
  end

  def handle_event("add_like", _params, socket) do
    Reaction.like(
      %{
        sender_id: socket.assigns.sender.id,
        receiver_id: socket.assigns.receiver.id
      },
      actor: socket.assigns.sender
    )

    broadcast_user(socket)

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.sender.id, socket.assigns.receiver.id)
     )}
  end

  @impl true
  def handle_event("remove_like", _params, socket) do
    reaction =
      get_reaction_for_sender_and_receiver(socket.assigns.sender.id, socket.assigns.receiver.id)

    Reaction.unlike(reaction, actor: socket.assigns.sender)
    broadcast_user(socket)

    {:noreply,
     socket
     |> assign(
       current_user_has_liked_profile?:
         current_user_has_liked_profile(socket.assigns.sender.id, socket.assigns.receiver.id)
     )}
  end

  @impl true
  def handle_event("validate", %{"message" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"message" => params}, socket) do
    case Message.create(params, actor: socket.assigns.sender) do
      {:ok, message} ->
        {:ok, messages_between_sender_and_receiver} =
          Message.messages_for_sender_and_receiver(message.sender_id, message.receiver_id,
            actor: socket.assigns.sender
          )

        PubSub.broadcast(Animina.PubSub, "messages", {:new_message, message})

        {:noreply,
         socket
         |> assign(messages: messages_between_sender_and_receiver)
         |> assign(form: create_message_form())}

      {:error, _} ->
        {:noreply, assign(socket, form: socket.assigns.form)}
    end
  end

  defp filter_flags(user, color, language) do
    user_flags =
      user.flags
      |> Enum.filter(fn x ->
        find_user_flag_for_a_flag(user.flags_join_assoc, x).color == color
      end)

    Enum.map(user_flags, fn user_flag ->
      %{
        id: user_flag.id,
        name: get_translation(user_flag.flag_translations, language),
        emoji: user_flag.emoji
      }
    end)
  end

  defp find_user_flag_for_a_flag(user_flags, flag) do
    Enum.find(user_flags, fn x -> x.flag_id == flag.id end)
  end

  defp get_reaction_for_sender_and_receiver(user_id, current_user_id) do
    {:ok, reaction} =
      Reaction.by_sender_and_receiver_id(user_id, current_user_id)

    reaction
  end

  defp message_belongs_to_current_user_or_profile(message, current_user, profile) do
    if (message.sender_id == current_user.id and message.receiver_id == profile.id) or
         (message.sender_id == profile.id and message.receiver_id == current_user.id) do
      true
    else
      false
    end
  end

  defp get_page_title(message, sender, receiver) do
    # if I am the one who has received the new message it should add the chat icon
    if message.receiver_id == sender.id do
      "💬 #{sender.username} <-> #{receiver.username} (animina chat)"
    else
      "#{sender.username} <-> #{receiver.username} (animina chat)"
    end
  end

  defp get_translation(translations, language) do
    language = String.split(language, "-") |> Enum.at(0)

    translation =
      Enum.find(translations, nil, fn translation -> translation.language == language end)

    translation.name
  end

  defp current_user_has_liked_profile(user_id, current_user_id) do
    case Reaction.by_sender_and_receiver_id(user_id, current_user_id) do
      {:ok, _user} ->
        true

      {:error, _} ->
        false
    end
  end

  def handle_info({:user, current_user}, socket) do
    intersecting_green_flags_count =
      get_intersecting_flags_count(
        filter_flags(current_user, :green, socket.assigns.language),
        filter_flags(socket.assigns.receiver, :white, socket.assigns.language)
      )

    intersecting_red_flags_count =
      get_intersecting_flags_count(
        filter_flags(current_user, :red, socket.assigns.language),
        filter_flags(socket.assigns.receiver, :white, socket.assigns.language)
      )

    if current_user.id == socket.assigns.receiver.id do
      {:noreply,
       socket
       |> assign(sender: current_user)
       |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
       |> assign(intersecting_red_flags_count: intersecting_red_flags_count)
       |> assign(
         current_user_has_liked_profile?:
           current_user_has_liked_profile(current_user.id, socket.assigns.receiver.id)
       )}
    else
      {:noreply,
       socket
       |> assign(intersecting_green_flags_count: intersecting_green_flags_count)
       |> assign(
         current_user_has_liked_profile?:
           current_user_has_liked_profile(current_user.id, socket.assigns.receiver.id)
       )
       |> assign(intersecting_red_flags_count: intersecting_red_flags_count)}
    end
  end

  def handle_info({:new_message, message}, socket) do
    {:ok, message} = Message.by_id(message.id)

    messages =
      (socket.assigns.messages ++ message)
      |> Enum.uniq()

    unread_messages = socket.assigns.unread_messages ++ [message]

    if message_belongs_to_current_user_or_profile(
         List.first(message),
         socket.assigns.sender,
         socket.assigns.receiver
       ) do
      page_title =
        get_page_title(List.first(message), socket.assigns.sender, socket.assigns.receiver)

      {:noreply,
       socket
       |> assign(page_title: page_title)
       |> assign(unread_messages: unread_messages)
       |> assign(number_of_unread_messages: Enum.count(unread_messages))
       |> assign(messages: messages)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_user(socket, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  defp get_intersecting_flags_count(first_flag_array, second_flag_array) do
    first_flag_array = Enum.map(first_flag_array, fn x -> x.id end)
    second_flag_array = Enum.map(second_flag_array, fn x -> x.id end)

    Enum.count(first_flag_array, &(&1 in second_flag_array))
  end

  defp create_message_form do
    Form.for_create(Message, :create,
      api: Accounts,
      as: "message",
      forms: [auto?: true]
    )
    |> to_form()
  end

  defp broadcast_user(socket) do
    current_user = User.by_id!(socket.assigns.current_user.id)

    PubSub.broadcast(
      Animina.PubSub,
      "#{current_user.username}",
      {:user, current_user}
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="md:h-[90vh] h-[85vh] relative  w-[100%] flex gap-4 flex-col justify-betwen">
      <.chat_messages_component
        sender={@sender}
        receiver={@receiver}
        messages={@messages}
        profile_points={@profile_points}
        current_user_has_liked_profile?={@current_user_has_liked_profile?}
        intersecting_green_flags_count={@intersecting_green_flags_count}
        intersecting_red_flags_count={@intersecting_red_flags_count}
        years_text={gettext("years")}
        centimeters_text={gettext("cm")}
      />
      <div class="w-[100%]  absolute bottom-0">
        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-submit="submit"
          class="w-[100%] flex justify-between items-end"
        >
          <div phx-feedback-for={f[:content].name} class="md:w-[93%] w-[90%]">
            <%= textarea(
              f,
              :content,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:content], :content) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Your message here..."),
              value: f[:content].value,
              type: :text,
              required: true,
              rows: 2,
              autocomplete: :content,
              "phx-debounce": "200"
            ) %>

            <%= hidden_input(f, :sender_id, value: @sender.id) %>
            <%= hidden_input(f, :receiver_id, value: @receiver.id) %>
          </div>

          <div class="md:w-[5%] w-[8%] flex justify-center items-center">
            <%= submit(
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.source.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.source.valid? == false
          ) do %>
              <.send_message_button />
            <% end %>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
